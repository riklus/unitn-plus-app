import 'package:http/http.dart';
import 'requests.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

const iphoneHeaders = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-GB,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate'
};

const clientId = 'it.unitn.icts.unitrentoapp';
const clientSecret = 'FplHsHYTvmMN7hvogSzf';

/// Initiate Authorization of a Session.
Future<StreamedResponse> initAuthorize(Requests s) async {
  final state =
      base64UrlEncode(await SecretKeyData.random(length: 7).extractBytes());
  final verifier =
      base64UrlEncode(await SecretKeyData.random(length: 96).extractBytes());
  final challenge =
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
Future<StreamedResponse> authenticate(
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
  var r = await s.post('https://idsrv.unitn.it/sts/identity/saml2service/Acs',
      headers: {
        ...iphoneHeaders,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: Uri(queryParameters: {
        'RelayState': relayState,
        'SAMLResponse': samlResponse
      }).query);

  print("RESPONSE: " + r.headers.toString());
  print(await r.stream.bytesToString());

  return '';
}

main() async {
  var s = Requests();
  // initAuthorization will redirect and ask for Authentication.
  await initAuthorize(s);

  // Authentication will return SAML form.
  var r = await authenticate(
      s, 'user', 'pass');
  var authNresBody = await r.stream.bytesToString();
  var samlResponse = extractSamlResponse(authNresBody);
  var relayState = extractRelayState(authNresBody);

  // Getting the authZcode.
  var authZcode = getAuthorizationCode(s, samlResponse, relayState);
}
