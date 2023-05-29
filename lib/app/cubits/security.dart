import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ouisync_plugin/ouisync_plugin.dart';

import '../../generated/l10n.dart';
import '../utils/loggers/ouisync_app_logger.dart';
import '../utils/utils.dart';
import '../widgets/inputs/password_validation_input.dart';
import 'cubits.dart';

class SecurityState extends Equatable {
  final bool isBiometricsAvailable;
  final bool unlockWithBiometrics;
  final String authMode;
  final String password;
  final bool previewPassword;
  final String message;

  PasswordMode get passwordMode => authMode == Constants.authModeManual
      ? PasswordMode.manual
      : authMode == Constants.authModeNoLocalPassword
          ? PasswordMode.none
          : PasswordMode.bio;

  String get passwordModeTitle => authMode == Constants.authModeManual
      ? 'Update local password'
      : 'Add local password';

  SecurityState(
      {this.isBiometricsAvailable = false,
      this.unlockWithBiometrics = false,
      this.authMode = '',
      this.password = '',
      this.previewPassword = false,
      this.message = ''});

  SecurityState copyWith(
          {bool? isBiometricsAvailable,
          bool? unlockWithBiometrics,
          String? authMode,
          String? password,
          bool? previewPassword,
          String? message}) =>
      SecurityState(
          isBiometricsAvailable:
              isBiometricsAvailable ?? this.isBiometricsAvailable,
          unlockWithBiometrics:
              unlockWithBiometrics ?? this.unlockWithBiometrics,
          authMode: authMode ?? this.authMode,
          password: password ?? this.password,
          previewPassword: previewPassword ?? this.previewPassword,
          message: message ?? this.message);

  @override
  List<Object?> get props => [
        isBiometricsAvailable,
        unlockWithBiometrics,
        authMode,
        password,
        previewPassword,
        message
      ];
}

class SecurityCubit extends Cubit<SecurityState> with OuiSyncAppLogger {
  SecurityCubit._(this._repoCubit, this._shareToken, SecurityState state)
      : super(state);

  final RepoCubit _repoCubit;
  ShareToken? _shareToken;

  void setShareToken(ShareToken shareToken) => _shareToken = shareToken;

  static SecurityCubit create(
      {required RepoCubit repoCubit,
      required ShareToken? shareToken,
      required bool isBiometricsAvailable,
      required String authenticationMode,
      required String password}) {
    var initialState = SecurityState();

    final unlockWithBiometrics = [
      Constants.authModeVersion1,
      Constants.authModeVersion2
    ].contains(authenticationMode);

    initialState = initialState.copyWith(
        isBiometricsAvailable: isBiometricsAvailable,
        unlockWithBiometrics: unlockWithBiometrics,
        authMode: authenticationMode,
        password: password);

    return SecurityCubit._(repoCubit, shareToken, initialState);
  }

  Future<String?> addRepoLocalPassword(String newPassword) async {
    final deleted = await _removePasswordFromSecureStorage(
        Constants.authModeNoLocalPassword);

    if (deleted == false) {
      setAuthMode(Constants.authModeNoLocalPassword);

      return S.current.messageErrorRemovingSecureStorage;
    }

    final changed = await _changeRepositoryPassword(newPassword);

    if (changed == false) {
      return S.current.messageErrorAddingLocalPassword;
    }

    setPassword(newPassword);
    setAuthMode(Constants.authModeManual);

    return null;
  }

  Future<String?> updateRepoLocalPassword(String newPassword) async {
    final changed = await _changeRepositoryPassword(newPassword);

    if (changed == false) {
      return S.current.messageErrorAddingLocalPassword;
    }

    setPassword(newPassword);
    return null;
  }

  Future<String?> removeRepoLocalPassword() async {
    final newPassword = generateRandomPassword();
    final passwordChanged = await _changeRepositoryPassword(newPassword);

    if (passwordChanged == false) {
      return S.current.messageErrorAddingSecureStorge;
    }

    setPassword(newPassword);

    final addedToSecureStorage = await _addPasswordToSecureStorage(
        newPassword, Constants.authModeNoLocalPassword);

    if (addedToSecureStorage == false) {
      return S.current.messageErrorRemovingPassword;
    }

    setAuthMode(Constants.authModeNoLocalPassword);

    return null;
  }

  Future<String?> updateUnlockRepoWithBiometrics(
      bool unlockWithBiometrics) async {
    if (unlockWithBiometrics == false) {
      final addedOrRemoved = await _addOrRemoveVersion2InSecureStorage(
          Constants.authModeNoLocalPassword);

      if (addedOrRemoved == null) {
        return 'addedOrRemoved == null';
      }

      if (addedOrRemoved == false) {
        return 'addedOrRemoved == false';
      }

      setUnlockWithBiometrics(false);
      setAuthMode(Constants.authModeNoLocalPassword);

      return null;
    }

    final newPassword = generateRandomPassword();
    final passwordChanged = await _changeRepositoryPassword(newPassword);

    if (passwordChanged == false) {
      return S.current.messageErrorAddingSecureStorge;
    }

    setPassword(newPassword);

    final updated = await _updatePasswordInSecureStorage(
        newPassword, Constants.authModeVersion2);

    if (updated == false) {
      setUnlockWithBiometrics(false);
      setPassword(newPassword);
      setAuthMode(Constants.authModeManual);

      return S.current.messageErrorUpdatingSecureStorage;
    }

    setUnlockWithBiometrics(true);
    setAuthMode(Constants.authModeVersion2);

    return null;
  }

  Future<bool> _addPasswordToSecureStorage(
      String password, String authMode) async {
    final secureStorageResult = await SecureStorage.addRepositoryPassword(
        databaseId: _repoCubit.databaseId,
        password: password,
        authMode: authMode);

    if (secureStorageResult.exception != null) {
      loggy.app(secureStorageResult.exception);
      return false;
    }

    return true;
  }

  Future<bool> _updatePasswordInSecureStorage(
      String newPassword, String authMode) async {
    final secureStorageResult = await SecureStorage.addRepositoryPassword(
        databaseId: _repoCubit.databaseId,
        password: state.password,
        authMode: authMode);

    if (secureStorageResult.exception != null) {
      loggy.app(secureStorageResult.exception);

      return false;
    }

    emit(state.copyWith(password: newPassword));

    return true;
  }

  Future<bool?> _addOrRemoveVersion2InSecureStorage(String newAuthMode) async {
    final newEntryResult = await SecureStorage.addRepositoryPassword(
        databaseId: _repoCubit.databaseId,
        password: state.password,
        authMode: newAuthMode);

    if (newEntryResult.exception != null) {
      loggy.app(newEntryResult.exception);

      return null;
    }

    final oldVersion2EntryResult = await SecureStorage.deleteRepositoryPassword(
        databaseId: _repoCubit.databaseId,
        authMode: state.authMode,
        authenticationRequired: false);

    if (oldVersion2EntryResult.exception != null) {
      loggy.app(oldVersion2EntryResult.exception);

      return false;
    }

    return true;
  }

  Future<bool> _removePasswordFromSecureStorage(String authMode) async {
    final secureStorageResult = await SecureStorage.deleteRepositoryPassword(
        databaseId: _repoCubit.databaseId,
        authMode: authMode,
        authenticationRequired: false);

    if (secureStorageResult.exception != null) {
      loggy.app(secureStorageResult.exception);

      return false;
    }

    emit(state.copyWith(unlockWithBiometrics: false, previewPassword: false));
    return true;
  }

  Future<bool> _changeRepositoryPassword(String newPassword) async {
    assert(_shareToken != null, 'ERROR: shareToken is null');
    assert(state.password.isNotEmpty, 'ERROR: currentPassword is empty');

    if (_shareToken == null || state.password.isEmpty) {
      return false;
    }

    final mode = await _shareToken?.mode;
    final metaInfo = _repoCubit.metaInfo;

    if (mode == AccessMode.write) {
      return _repoCubit.setReadWritePassword(
          metaInfo, state.password, newPassword, _shareToken);
    } else {
      assert(mode == AccessMode.read);
      return _repoCubit.setReadPassword(metaInfo, newPassword, _shareToken);
    }
  }

  void setUnlockWithBiometrics(bool value) =>
      emit(state.copyWith(unlockWithBiometrics: value));

  void setPassword(String password) => emit(state.copyWith(password: password));

  void setAuthMode(String authMode) {
    if (state.authMode == authMode) {
      return;
    }

    _repoCubit.setAuthenticationMode(authMode);

    emit(state.copyWith(authMode: authMode));
  }
}
