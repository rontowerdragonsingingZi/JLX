import 'package:flutter/material.dart';

import '../../data/models/cloud_auth_result.dart';
import '../../services/cloud_auth_api.dart';
import '../../services/forum/forum_cloud_auth_api.dart';
import '../../theme/app_theme.dart';

enum _AuthMode { login, register }

Future<CloudAuthResult?> showAuthDialog(
  BuildContext context, {
  CloudAuthApi? cloudAuthApi,
}) {
  return showDialog<CloudAuthResult>(
    context: context,
    builder: (context) => AuthDialog(cloudAuthApi: cloudAuthApi),
  );
}

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key, CloudAuthApi? cloudAuthApi})
      : _cloudAuthApi = cloudAuthApi;

  final CloudAuthApi? _cloudAuthApi;

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  late final CloudAuthApi _cloudAuthApi =
      widget._cloudAuthApi ?? ForumCloudAuthApi();

  _AuthMode _mode = _AuthMode.login;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mode == _AuthMode.register &&
        _passwordController.text != _confirmController.text) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final CloudAuthResult result;
      if (_mode == _AuthMode.login) {
        result = await _cloudAuthApi.login(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        result = await _cloudAuthApi.register(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on CloudAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isLogin ? '登录您的账号' : '创建新账号',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '用户名'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
                textInputAction:
                    isLogin ? TextInputAction.done : TextInputAction.next,
                onSubmitted: isLogin ? (_) => _submit() : null,
              ),
              if (!isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmController,
                  decoration: const InputDecoration(labelText: '确认密码'),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isLogin ? '登录' : '注册'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? '还没有账号？' : '已有账号？',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _mode = isLogin
                                  ? _AuthMode.register
                                  : _AuthMode.login;
                              _error = null;
                            });
                          },
                    child: Text(isLogin ? '注册' : '登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}