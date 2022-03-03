import 'dart:io';
import 'package:http/http.dart' as http;

/// Simple Requests class to make cookie persistant requests.
/// Requests doesn't check the date of the cookie and cookies are matched by
/// their host and not their domain.
class Requests {
  Map<String, List<Cookie>> cookieJar = {};

  /// Get request with optional queryParameters.
  Future<http.StreamedResponse> get(String url,
      {Map<String, String>? headers,
      Map<String, dynamic>? queryParameters}) async {
    var baseClient = http.Client();

    Uri uri = Uri.parse(url);
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    http.StreamedResponse r;
    do {
      var req = http.Request('Get', uri)
        ..followRedirects = false
        ..headers.addAll({'Cookie': _getCookies(uri.host)})
        ..headers.addAll(headers ?? {});
      r = await baseClient.send(req);
      _pushCookie(r.headers, uri.host);

      uri = uri.resolve(r.headers['location'] ?? '');
    } while (r.isRedirect);

    return r;
  }

  Future<http.StreamedResponse> post(String url,
      {Map<String, String>? headers,
      Map<String, dynamic>? queryParameters,
      String? body}) async {
    var method = 'Post';
    var baseClient = http.Client();

    Uri uri = Uri.parse(url);
    if (queryParameters != null) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    http.StreamedResponse r;
    do {
      print(method.toUpperCase() + ':');
      print("URI:" + uri.toString());
      print("Cookie: " + _getCookies(uri.host));
      //print(body ?? '');
      var req = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll({'Cookie': _getCookies(uri.host)})
        ..headers.addAll(headers ?? {})
        ..body = body ?? '';
      r = await baseClient.send(req);
      _pushCookie(r.headers, uri.host);

      uri = uri.resolve(r.headers['location'] ?? '');
      method = 'Get';
    } while (r.isRedirect);

    return r;
  }

  /// Pushes cookie in the cookieJar if set-cookie is present in the headers.
  _pushCookie(Map<String, String> headers, String host) {
    if (headers.containsKey('set-cookie')) {
      var setCookie = headers['set-cookie'] ?? '';

      // Parsing multiple cookies.
      // var cookies = setCookie.split(RegExp(r","));

      // for (var i = 0; i < cookies.length; i++) {
      //   if (cookies[i].contains(RegExp(r"expires=[^=]{3}$"))) {
      //     // Merge cookie splits if it's an expires value that has a comma.
      //     if (i + 1 < cookies.length) cookies[i] += cookies[i + 1];
      //     cookies.removeAt(i + 1);
      //     i++;
      //   }
      // }
      // Used by http dart to differentiate cookies
      var cookies = setCookie.split('|');

      for (String c in cookies) {
        var cookie = Cookie.fromSetCookieValue(c);

        if (cookieJar[host] == null) cookieJar[host] = [];

        // Update the cookie if present.
        var cookiePresent = false;
        for (var i = 0; i < cookieJar[host]!.length; i++) {
          if (cookieJar[host]![i].name == cookie.name &&
              cookieJar[host]![i].domain == cookie.domain &&
              cookieJar[host]![i].path == cookie.path) {
            cookieJar[host]![i] = cookie;
            cookiePresent = true;
            break;
          }
        }

        // Add cookie if not present.
        if (!cookiePresent) cookieJar[host]!.add(cookie); // Bad implementation
      }
    }
  }

  /// Get all the cookies as a single String from the cookieJar.
  String _getCookies(String host) {
    String retval = "";

    cookieJar[host]?.forEach((c) {
      if (c.value != '') retval += c.name + '=' + c.value + '; ';
    });

    if (retval.length >= 2) {
      return retval.substring(0, retval.length - 2);
    } else {
      return retval;
    }
  }
}
