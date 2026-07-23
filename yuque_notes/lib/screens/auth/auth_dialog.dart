import 'package:flutter/material.dart';

import '../../app_branding.dart';
import '../../data/models/cloud_auth_result.dart';
import '../../services/cloud_auth_api.dart';
import '../../services/forum/forum_cloud_auth_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_feedback_dialog.dart';
import '../../widgets/app_logo.dart';

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
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }

    setState(() {
      _sendingCode = true;
      _error = null;
      _info = null;
    });

    try {
      final retryAfterSeconds =
          await _cloudAuthApi.sendVerificationCode(email: email);
      if (!mounted) {
        return;
      }
      setState(() {
        _info = retryAfterSeconds == null
            ? '验证码已发送'
            : '验证码已发送，${retryAfterSeconds} 秒后可再次发送';
      });
    } on CloudAuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_mode == _AuthMode.register) {
      if (_passwordController.text != _confirmController.text) {
        setState(() => _error = '两次输入的密码不一致');
        return;
      }
      if (_emailController.text.trim().isEmpty) {
        setState(() => _error = '请输入邮箱');
        return;
      }
      if (_verificationCodeController.text.trim().isEmpty) {
        setState(() => _error = '请输入验证码');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final isLogin = _mode == _AuthMode.login;
    try {
      final CloudAuthResult result;
      if (isLogin) {
        result = await _cloudAuthApi.login(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        result = await _cloudAuthApi.register(
          username: _usernameController.text,
          password: _passwordController.text,
          email: _emailController.text,
          verificationCode: _verificationCodeController.text,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      await showSuccessDialog(
        context,
        title: isLogin ? '登录成功' : '注册成功',
        message: isLogin
            ? '欢迎回来，${result.username}！'
            : '账号 ${result.username} 已创建，欢迎使用 ${AppBranding.fullName}。',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on CloudAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
      await showErrorDialog(
        context,
        title: isLogin ? '登录失败' : '注册失败',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final msg = e.toString();
      setState(() {
        _loading = false;
        _error = msg;
      });
      await showErrorDialog(
        context,
        title: isLogin ? '登录失败' : '注册失败',
        message: msg,
      );
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    final colors = context.appColors;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 720;
    final horizontalInset = compact ? 16.0 : 40.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: compact ? 24 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 20 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppLogo(size: compact ? 64 : 88)),
              const SizedBox(height: 16),
              Text(
                isLogin ? AppBranding.loginTitle : AppBranding.registerTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
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
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '邮箱'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                if (compact) ...[
                  TextField(
                    controller: _verificationCodeController,
                    decoration: const InputDecoration(labelText: '邮箱验证码'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _sendingCode ? null : _sendVerificationCode,
                      style: buildAppOutlinedButtonStyle(colors),
                      child: _sendingCode
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('发送验证码'),
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _verificationCodeController,
                          decoration:
                              const InputDecoration(labelText: '邮箱验证码'),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              _sendingCode ? null : _sendVerificationCode,
                          style: buildAppOutlinedButtonStyle(colors),
                          child: _sendingCode
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('发送验证码'),
                        ),
                      ),
                    ],
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: colors.error, fontSize: 13),
                ),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(
                  _info!,
                  style: TextStyle(color: colors.primary, fontSize: 13),
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
                    style: TextStyle(color: colors.textSecondary),
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
                              _info = null;
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
