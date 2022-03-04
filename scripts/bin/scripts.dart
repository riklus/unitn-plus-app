import 'requests.dart';

void main(List<String> arguments) async {
  var s = Requests();
  var r = await s.get("https://www.microsoft.com/");
  print(await r.text());
  return;
}
