import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';

class LocalUserService {
  LocalUserService({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  Future<User> ensureLocalUser() {
    return _authRepository.ensureLocalUser();
  }
}