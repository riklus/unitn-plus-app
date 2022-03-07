import 'requests.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'credentials.dart' as credentials;

const iphoneHeaders = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-GB,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate'
};

const clientId = 'it.unitn.icts.unitrentoapp';
const clientSecret = 'FplHsHYTvmMN7hvogSzf';
String state = '', verifier = '', challenge = '';

/// Initiate Authorization of a Session.
Future<ApiResponse> initAuthorize(Requests s) async {
  state = base64UrlEncode(await SecretKeyData.random(length: 7).extractBytes());
  verifier =
      base64UrlEncode(await SecretKeyData.random(length: 96).extractBytes());
  challenge =
      base64UrlEncode((await Sha256().hash(utf8.encode(verifier))).bytes);

  return s.get('https://idsrv.unitn.it/sts/identity/connect/authorize',
      headers: iphoneHeaders,
      queryParameters: {
        'redirect_uri': 'unitrentoapp://callback',
        'client_id': clientId,
        'response_type': 'code',
        'scope':
            'openid profile account email offline_access icts://unitrentoapp/preferences icts://servicedesk/support icts://studente/carriera icts://opera/mensa',
        'access_type': 'offline',
        'client_secret': clientSecret,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256'
      });
}

/// Authenticates a Session (login).
Future<ApiResponse> authenticate(
    Requests s, String username, String password) async {
  return s.post(
      'https://idp.unitn.it/idp/profile/SAML2/Redirect/SSO?execution=e1s1',
      headers: {
        ...iphoneHeaders,
        'Referer':
            'https://idp.unitn.it/idp/profile/SAML2/Redirect/SSO?execution=e1s1',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: Uri(queryParameters: {
        'j_username': username,
        'j_password': password,
        'dominio': '@unitn.it',
        '_eventId_proceed': ''
      }).query);
}

/// Extracts the SAML Response from the SAMLform.
String extractSamlResponse(String body) {
  var regex = RegExp(r'name="(SAMLResponse)" value="(.*?)"', multiLine: true);
  return regex.firstMatch(body)!.group(2)!;
}

/// Extracts the RelayState (callback://unitrentoapp) from the SAMLform.
String extractRelayState(String body) {
  var regex = RegExp(r'name="(RelayState)" value="(.*?)"', multiLine: true);
  return regex.firstMatch(body)!.group(2)!;
}

/// Retrives authZcode from server by using SAMLResponse.
Future<String> getAuthorizationCode(
    Requests s, String samlResponse, String relayState) async {
  String code = '';
  try {
    await s.post('https://idsrv.unitn.it/sts/identity/saml2service/Acs',
        headers: {
          ...iphoneHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: Uri(queryParameters: {
          'RelayState': relayState,
          'SAMLResponse': samlResponse
        }).query);
  } catch (e) {
    var regex = RegExp(r'code=(.*?)&');
    var g = regex.firstMatch(e.toString());
    code = g!.group(1) ?? '';
    print(e);
  }

  return code;
}

Future<String> getUnitnToken(String authZcode) async {
  var r =
      await Requests().post('https://idsrv.unitn.it/sts/identity/connect/token',
          headers: {
            ...iphoneHeaders,
            'Accept': 'application/json, text/plain, */*',
            'Unitn-Culture': 'it',
            'Origin': 'capacitor://localhost',
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: Uri(queryParameters: {
            'grant_type': 'authorization_code',
            'client_id': clientId,
            'client_secret': clientSecret,
            'redirect_uri': 'unitrentoapp://callback',
            'code': authZcode,
            'code_verifier': verifier
          }).query);

  return '';
}

main() async {
  var s = Requests();
  // initAuthorization will redirect and ask for Authentication.
  (await initAuthorize(s)).close();

  // Authentication will return SAML form.
  var r = await authenticate(s, credentials.user, credentials.pass);
  var authNresBody = await r.text();
  var samlResponse = extractSamlResponse(authNresBody);
  var relayState = extractRelayState(authNresBody);

  // Getting the authZcode.
  var authZcode = await getAuthorizationCode(s, samlResponse, relayState);
  print(authZcode);

  // Getting Unitn Token.
  var token = await getUnitnToken(authZcode);
}
