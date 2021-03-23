import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ouisync_app/callbacks/nativecallbacks.dart';

import '../../controls/controls.dart';
import '../../models/models.dart';

class OuisyncRepository {
  void createRepository(String repoDir, String newRepoPath) {
    String path = '$repoDir/$newRepoPath';
    NativeCallbacks.initializeOuisyncRepository(path);
  }

  Future<List<BaseItem>> getRepositories(String repoDir) async {
    print('Reading user repositories at $repoDir');
    
    bool exist = await Directory(repoDir).exists();
    if(!exist) {
      print('Repository location $repoDir doesn\'t exist');
      return [];
    }

    List<BaseItem> reposList = [];
    
    await Directory(repoDir).list().toList()
    .catchError((onError) {
      print('Error reading $repoDir contents: $onError');
    })
    .then((repos) => {
        print('Repositories found: ${repos.length}'),
        reposList = _castToBaseItem(repos)
    })
    .whenComplete(() => {
      print('Done reading repositories')
    });
    
    return reposList;
  }

  List<BaseItem> _castToBaseItem(List<FileSystemEntity> repos) {
    List<BaseItem> newList = repos.map((repo) => 
      FolderItem(
        "",
        _removeParentPathSection(repo.path),
        repo.path,
        0.0,
        SyncStatus.idle,
        User(id: '', name: ''),
        itemType: ItemType.repo,
        icon: Icons.store,
      )
    ).toList();

    return newList;
  }
  
  String _removeParentPathSection(String path) {
    return path.split('/').last;
  }
}