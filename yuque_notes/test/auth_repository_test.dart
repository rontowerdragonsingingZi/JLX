import 'package:flutter_test/flutter_test.dart';
import 'package:yuque_notes/data/repositories/auth_repository.dart';

import 'helpers/test_setup.dart';

void main() {
  late AuthRepository authRepository;

  setUp(() async {
    await setUpTestDatabase();
    authRepository = AuthRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('register creates user and login succeeds', () async {
    final user = await authRepository.register(
      username: 'alice',
      password: 'secret123',
    );

    expect(user.id, greaterThan(0));
    expect(user.username, 'alice');

    final loggedIn = await authRepository.login(
      username: 'alice',
      password: 'secret123',
    );
    expect(loggedIn.id, user.id);
    expect(loggedIn.username, 'alice');
  });

  test('login fails with wrong password', () async {
    await authRepository.register(username: 'bob', password: 'pass');

    expect(
      () => authRepository.login(username: 'bob', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('register rejects duplicate username', () async {
    await authRepository.register(username: 'carol', password: 'pass');

    expect(
      () => authRepository.register(username: 'carol', password: 'other'),
      throwsA(isA<AuthException>()),
    );
  });

  test('hashPassword is deterministic', () {
    final hash1 = authRepository.hashPassword('test');
    final hash2 = authRepository.hashPassword('test');
    expect(hash1, hash2);
    expect(hash1, isNot(equals(authRepository.hashPassword('other'))));
  });

  test('ensureLocalUser uses stable __local__ username', () async {
    final created = await authRepository.ensureLocalUser();
    expect(created.username, AuthRepository.localUsername);

    final reloaded = await authRepository.ensureLocalUser();
    expect(reloaded.username, AuthRepository.localUsername);
    expect(reloaded.id, created.id);
  });

  test('ensureCloudLinkedLocalUser creates sync-eligible local owner', () async {
    final linked = await authRepository.ensureCloudLinkedLocalUser(
      cloudUsername: 'alice',
    );
    expect(linked.username, 'alice');
    expect(AuthRepository.isLocalGuest(linked), isFalse);

    final same = await authRepository.ensureCloudLinkedLocalUser(
      cloudUsername: 'alice',
    );
    expect(same.id, linked.id);
  });

  test('updateAvatar persists and reloads via getUserById and login', () async {
    final user = await authRepository.register(
      username: 'dave',
      password: 'secret',
    );
    expect(user.avatar, isNull);

    const avatar = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z5BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    await authRepository.updateAvatar(userId: user.id, avatar: avatar);

    final reloaded = await authRepository.getUserById(user.id);
    expect(reloaded?.avatar, avatar);

    final loggedIn = await authRepository.login(
      username: 'dave',
      password: 'secret',
    );
    expect(loggedIn.avatar, avatar);
  });
}