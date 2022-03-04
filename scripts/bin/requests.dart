import 'dart:convert';
import 'dart:io';
import 'dart:async';

class ApiResponse {
  HttpClientResponse response;
  HttpClient client;

  ApiResponse(this.response, this.client);

  Future<String> text() async {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    var c = await completer.future;
    close();
    return c;
  }

  close() {
    client.close(force: true);
  }
}

/// Simple Requests class to make cookie persistant requests.
/// Requests doesn't check the date of the cookie and cookies are matched by
/// their host and not their domain.
class Requests {
  Map<String, List<Cookie>> cookieJar = {};

  /// Get request with optional queryParameters.
  Future<ApiResponse> get(String url,
      {Map<String, String>? headers,
      Map<String, dynamic>? queryParameters}) async {
    var client = HttpClient();
    client.userAgent = null;
    HttpClientResponse r;
    try {
      Uri uri = Uri.parse(url);
      if (queryParameters != null) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      do {
        var req = await client.getUrl(uri)
          ..followRedirects = false
          ..headers.add('Cookie', _getCookies(uri.host));

        headers?.forEach((key, value) {
          req.headers.add(key, value);
        });

        r = await req.close();
        _pushCookie(r.headers, uri.host);

        uri = uri.resolve(r.headers.value('location') ?? '');
      } while (r.isRedirect);
    } catch (e) {
      rethrow;
    } finally {
      client.close(force: true);
    }
    return ApiResponse(r, client);
  }

  Future<ApiResponse> post(String url,
      {Map<String, String>? headers,
      Map<String, dynamic>? queryParameters,
      String? body}) async {
    var client = HttpClient();
    client.userAgent = null;
    var method = 'Post';

    HttpClientResponse r;

    try {
      Uri uri = Uri.parse(url);
      if (queryParameters != null) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      do {
        var req = await client.openUrl(method, uri)
          ..followRedirects = false
          ..headers.add('Cookie', _getCookies(uri.host));

        headers?.forEach((key, value) {
          req.headers.add(key, value);
        });
        if (body != null) req.write(body);

        r = await req.close();
        _pushCookie(r.headers, uri.host);

        uri = uri.resolve(r.headers.value('location') ?? '');
        method = 'Get';
        body = null;
      } while (r.isRedirect);
    } catch (e) {
      rethrow;
    } finally {
      client.close(force: true);
    }
    return ApiResponse(r, client);
  }

  /// Pushes cookie in the cookieJar if set-cookie is present in the headers.
  _pushCookie(HttpHeaders headers, String host) {
    var cookies = headers['set-cookie'] ?? [];

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
