import 'package:flutter/material.dart';
import 'package:ouisync_plugin/ouisync_plugin.dart';

import '../../../generated/l10n.dart';
import '../../cubits/cubits.dart';
import '../../models/repo_entry.dart';
import '../../utils/utils.dart';
import '../../utils/loggers/ouisync_app_logger.dart';
import '../widgets.dart';

class RepositoriesBar extends StatelessWidget with PreferredSizeWidget {
  const RepositoriesBar({
    required this.reposCubit,
    required this.shareRepositoryOnTap
  });

  final ReposCubit reposCubit;
  final void Function(RepoCubit) shareRepositoryOnTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(width: 1.0, color: Colors.transparent, style: BorderStyle.solid),
        ),
      ),
      padding: Dimensions.paddingRepositoryBar,
      child: Row(
        children: [
          Expanded(
            child: _Picker(
              reposCubit: reposCubit,
              shareRepositoryOnTap: shareRepositoryOnTap,
              borderColor: Colors.white,
            ),
          ),
          Fields.actionIcon(
            const Icon(Icons.share_outlined),
            onPressed: () {
              final current = reposCubit.currentRepo;
              if (current is! OpenRepoEntry) return;
              shareRepositoryOnTap(current.cubit);
            },
            size: Dimensions.sizeIconSmall,
            color: Colors.white,
          )
        ],
      )
    );
  }

  @override
  Size get preferredSize {
    // TODO: This value was found experimentally, can it be done programmatically?
    return const Size.fromHeight(58);
  }
}

class _Picker extends StatelessWidget {
  static const Color colorNoRepo = Colors.grey;
  static const Color colorLockedRepo = Colors.grey;
  static const Color colorUnlockedRepo = Colors.black;
  static const Color colorError = Colors.red;

  const _Picker({
    required this.reposCubit,
    required this.shareRepositoryOnTap,
    required this.borderColor,
  });

  final ReposCubit reposCubit;
  final void Function(RepoCubit) shareRepositoryOnTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context)  => reposCubit.builder((state) {
    if (state.isLoading) {
      return Column(children: const [CircularProgressIndicator(color: Colors.white)],);
    }

    final repo = state.currentRepo;
    final name = _repoName(repo);

    if (repo == null) {
      return _buildState(
        context,
        borderColor: borderColor,
        iconColor: colorNoRepo,
        textColor: colorNoRepo,
        repoName: name,
      );
    }

    final color = repo is! OpenRepoEntry || repo.cubit.accessMode == AccessMode.blind
        ? colorLockedRepo
        : colorUnlockedRepo;

    return _buildState(
      context,
      borderColor: borderColor,
      iconColor: colorUnlockedRepo,
      textColor: color,
      repoName: name,
    );
  });

  String _repoName(RepoEntry? repo) {
    if (repo != null) {
      return repo.name;
    } else {
      return S.current.messageNoRepos;
    }
  }

  _buildState(
    BuildContext context, {
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    required String repoName,
  }) => Container(
    padding: Dimensions.paddingepositoryPicker,
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(Dimensions.radiusSmall)),
      border: Border.all(
        color: borderColor,
        style: BorderStyle.solid
      ),
      color: Colors.white,
    ),
    child: InkWell(
      onTap: () async { await _showRepositorySelector(context); },
      child: Row(
        children: [
          Icon(
            Icons.cloud_outlined,
            size: Dimensions.sizeIconSmall,
            color: iconColor,
          ),
          Dimensions.spacingHorizontal,
          Fields.constrainedText(
            repoName,
            softWrap: false,
            textOverflow: TextOverflow.fade,
            color: textColor
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.keyboard_arrow_down_outlined,
              color: iconColor
            )
          ),
        ]
      )
    )
  );

  Future<dynamic> _showRepositorySelector(BuildContext context) => showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    shape: Dimensions.borderBottomSheetTop,
    builder: (context) {
      return _List(
        reposCubit,
        shareRepositoryOnTap);
    }
  );
}

class _List extends StatelessWidget with OuiSyncAppLogger {
  _List(ReposCubit repositories, void Function(RepoCubit) shareRepositoryOnTap) : 
  _repositories = repositories,
  _shareRepositoryOnTap = shareRepositoryOnTap;

  final ReposCubit _repositories;
  final void Function(RepoCubit) _shareRepositoryOnTap;

  @override
  Widget build(BuildContext context) => _repositories.builder((state) {
    return Container(
      padding: Dimensions.paddingBottomSheet,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Fields.bottomSheetHandle(context),
          Fields.bottomSheetTitle(S.current.titleRepositoriesList),
          _buildRepositoryList(
            context,
            state.repositoryNames().toList(),
            state.currentRepoName),
          Dimensions.spacingActionsVertical,
          Fields.paddedActionText(
            S.current.iconAddRepository.toUpperCase(),
            textFontSize: Dimensions.fontAverage,
            textColor: Constants.primaryColor(context),
            textFontWeight: FontWeight.w600,
            icon: Icons.add,
            iconSize: Dimensions.sizeIconSmall,
            iconColor: Constants.primaryColor(context),
            onTap: () => createRepoDialog(context),
          ),
          Fields.paddedActionText(
            S.current.iconAddRepositoryWithToken.toUpperCase(),
            textFontSize: Dimensions.fontAverage,
            textColor: Constants.primaryColor(context),
            textFontWeight: FontWeight.w600,
            icon: Icons.insert_link_rounded,
            iconSize: Dimensions.sizeIconSmall,
            iconColor: Constants.primaryColor(context),
            onTap: () => addRepoWithTokenDialog(context),
          ),
        ]
      ),
    );
  });

  Widget _buildRepositoryList(BuildContext context, List<String> repoNames, String? current) => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: repoNames.length,
    itemBuilder: (context, index) {
      final repositoryName = repoNames[index];
      AccessMode? accessMode = _repositories.get(repositoryName)?.maybeHandle?.accessMode;

      return Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(child:Fields.paddedActionText(
            repositoryName,
            textOverflow: TextOverflow.ellipsis,
            textSoftWrap: false,
            onTap: () {
              _repositories.setCurrentByName(repositoryName);
              updateSettingsAndPop(context, repositoryName);
            },
            icon: _selectIconByAccessMode(accessMode),
            iconSize: Dimensions.sizeIconAverage,
            iconColor: repositoryName == current
              ? Colors.black87
              : Colors.black54,
            textColor: repositoryName == current
              ? Colors.black87
              : Colors.black54,
            textFontWeight: repositoryName == current
              ? FontWeight.bold
              : FontWeight.normal,)),
            _getActionByAccessMode(
              context,
              repositoryName,
              accessMode,
              _repositories.get(repositoryName)?.maybeCubit),
        ],);
    }
  );

  IconData _selectIconByAccessMode(AccessMode? accessMode) {
    late final IconData modeIcon;
    switch (accessMode) {
      case AccessMode.blind:
        modeIcon = Icons.visibility_off_outlined;
        break;
      case AccessMode.read:
        modeIcon = Icons.visibility_outlined;
        break;
      case AccessMode.write:
        modeIcon = Icons.edit_note_rounded;//Icons.save_as_outlined;
        break;
      default:
        modeIcon = Icons.error_outline_rounded;
        break;
    }

    return modeIcon;
  }

  _getActionByAccessMode(
    BuildContext context,
    String repositoryName,
    AccessMode? accessMode,
    RepoCubit? cubit) {
      final modeIcon = accessMode == null
      ? Icons.error_outline_rounded
      : accessMode == AccessMode.blind
      ? Icons.lock_open_outlined
      : Icons.lock_outline;

      return Row(
        children: [
          Fields.actionIcon(Icon(modeIcon),
            onPressed: () async {
              if (cubit == null) return;
              if (accessMode == null) return;

              if (accessMode == AccessMode.blind) {
                await _unlockRepositoryDialog(
                  context,
                  repositoryName,
                );

                return;  
              }
            },
            color: Colors.black87,
            size: Dimensions.sizeIconAverage),
          Fields.actionIcon(const Icon(Icons.share),
            onPressed: () {
              if (cubit == null) return;
              
              // TODO: Should we dismiss the repo list or leave it open to return to it... ?
              // Navigator.of(context).pop();
              _shareRepositoryOnTap(cubit);
            },
            color: Colors.black87,
            size: Dimensions.sizeIconAverage)
        ],);
  }

  Future _unlockRepositoryDialog(BuildContext context, String repositoryName) async {
    final password = await showDialog(
      context: context,
      builder: (BuildContext context) {
        final formKey = GlobalKey<FormState>();

        return ActionsDialog(
          title: S.current.messageUnlockRepository,
          body: UnlockRepository(
            context: context,
            formKey: formKey,
            repositoryName:  repositoryName
          ),
        );
      }
    );

    _repositories.unlockRepository(
      _repositories.internalRepoMetaInfo(repositoryName),
      password: password
    );
  }

  void createRepoDialog(BuildContext context) async {
    final newRepo = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final formKey = GlobalKey<FormState>();

        return ActionsDialog(
          title: S.current.titleCreateRepository,
          body: RepositoryCreation(
            context: context,
            cubit: _repositories,
            formKey: formKey,
          ),
        );
      }
    );
    await updateSettingsAndPop(context, newRepo);
  }

  void addRepoWithTokenDialog(BuildContext context) async {
    final addedRepo = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final formKey = GlobalKey<FormState>();

        return ActionsDialog(
          title: S.current.titleAddRepository,
          body: AddRepositoryWithToken(
            context: context,
            cubit: _repositories,
            formKey: formKey,
          ),
        );
      }
    );

    await updateSettingsAndPop(context, addedRepo);
  }

  Future<void> updateSettingsAndPop(BuildContext context, String repositoryName) async {
    await _repositories.settings.setDefaultRepo(repositoryName);
    Navigator.of(context).pop();
  }
}
