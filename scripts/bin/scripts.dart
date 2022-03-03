import 'requests.dart';

void main(List<String> arguments) async {
  var s = Requests();
  var r = await s.get("https://pentoleprofessionali.it");
  print(s.cookieJar["opera4u.operaunitn.cloud"]);
  return;
}
