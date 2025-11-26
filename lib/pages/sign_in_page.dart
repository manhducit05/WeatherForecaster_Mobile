
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:supertokens_flutter/dio.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool isChecked = false;
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();

  bool isBoxReady = false;
  late Box box1;

  @override
  void initState() {
    super.initState();
    createBox();

  }
  void createBox() {
    box1 = Hive.box('logininfo');
    getdata();
    isBoxReady = true;
    setState(() {});
  }

  void getdata()async {
    if (box1.get('email') != null) {
      email.text = box1.get('email');
      isChecked = true;
      setState(() {

      });
    }
    if (box1.get('password') != null) {
      password.text = box1.get('password');
      isChecked = true;
      setState(() {

      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!isBoxReady) {
      return const Center(child: CircularProgressIndicator());
    }
    else return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/login.png'), fit: BoxFit.cover),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(),
            Container(
              padding: EdgeInsets.only(left: 35, top: 130),
              child: Text(
                'Welcome\nBack',
                style: TextStyle(color: Colors.white, fontSize: 33),
              ),
            ),
            SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery
                        .of(context)
                        .size
                        .height * 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(left: 35, right: 35),
                      child: Column(
                        children: [
                          TextField(
                            controller: email,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                                fillColor: Colors.grey.shade100,
                                filled: true,
                                hintText: "Email",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                )),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          TextField(
                            controller: password,
                            style: TextStyle(),
                            obscureText: true,
                            decoration: InputDecoration(
                                fillColor: Colors.grey.shade100,
                                filled: true,
                                hintText: "Password",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                )),
                          ),
                          SizedBox(
                            height: 40,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("Remember Me",
                                style: TextStyle(color: Colors.black),),
                              Checkbox(
                                value: isChecked,
                                onChanged: (value) {
                                  isChecked = !isChecked;
                                  setState(() {

                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sign in',
                                style: TextStyle(
                                    fontSize: 27, fontWeight: FontWeight.w700),
                              ),
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Color(0xff4c505b),
                                child: IconButton(
                                    color: Colors.white,
                                    onPressed: () {
                                      if (!isBoxReady) return;
                                      login();
                                    },
                                    icon: Icon(
                                      Icons.arrow_forward,
                                    )),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 40,
                          ),


                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                child: Text(
                                  'Sign Up',
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Color(0xff4c505b),
                                      fontSize: 18),
                                ),
                                style: ButtonStyle(),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void login() async {
    if (!box1.isOpen) return; // nếu box chưa mở, thoát
    // Lưu email/password nếu tick "Remember Me"
    if (isChecked) {
      box1.put('email', email.text);
      box1.put('password', password.text);
    }
    try {
      Dio dio = Dio();
      // Thêm SuperTokens interceptor để tự quản lý session
      dio.addSupertokensInterceptor();

      // URL API signup/login
      String url = "http://36.50.63.53:8080/auth/signin";

      Map<String, dynamic> body = {
        "formFields": [
          {"id": "email", "value": email.text},
          {"id": "password", "value": password.text},
        ]
      };
      // Gửi POST request
      Response response = await dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            "Content-Type": "application/json; charset=utf-8",
          },
        ),
      );

      if (response.data["status"] == "OK") {
        debugPrint("Đăng nhập thành công!");
        Navigator.pushReplacementNamed(context, '/');
      } else {
        debugPrint("Đăng nhập thất bại: ${response.data}");
      }
    } catch (e) {
      debugPrint("Lỗi request: $e");
    }
  }
}
