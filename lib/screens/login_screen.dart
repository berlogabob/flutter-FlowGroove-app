import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Контроллеры для полей ввода
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Переменная для переключения между входом и регистрацией
  bool _isLogin = true; // true = вход, false = регистрация

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RepSync')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Заголовок
            Text(
              _isLogin ? 'Вход' : 'Регистрация',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),

            // Поле email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Поле пароль
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true, // скрывает пароль
            ),
            const SizedBox(height: 32),

            // Кнопка действия (Войти / Зарегистрироваться)
            ElevatedButton(
              onPressed: () {
                // Пока просто выводим в консоль
                print(_isLogin ? 'Попытка входа' : 'Попытка регистрации');
                print('Email: ${_emailController.text}');
                print('Пароль: ${_passwordController.text}');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
            ),
            const SizedBox(height: 16),

            // Переключатель: "Нет аккаунта? Зарегистрируйтесь" или наоборот
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin; // переключаем режим
                });
              },
              child: Text(
                _isLogin
                    ? 'Нет аккаунта? Зарегистрируйтесь'
                    : 'Уже есть аккаунт? Войдите',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
