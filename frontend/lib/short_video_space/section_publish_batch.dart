part of 'section.dart';

/// Extension containing P8 multi-select and batch operations for ShortVideoSpaceSection.
/// Includes batch scheduling, publishing, archiving, and draft comparison.
extension ShortVideoPublishBatch on _ShortVideoSpaceSectionState {
  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      }
    });
  }

  void _toggleDraftSelection(String draftId) {
    setState(() {
      final next = Set<String>.from(_selectedDraftIds);
      if (next.contains(draftId)) {
        next.remove(draftId);
      } else {
        next.add(draftId);
      }
      _selectedDraftIds = next;
      _batchValidation = null;
    });
  }

  void _selectAllDrafts() {
    setState(() {
      _selectedDraftIds = _publishDrafts.map((d) => d.id).toSet();
      _batchValidation = null;
    });
  }

  void _clearDraftSelection() {
    setState(() {
      _selectedDraftIds = <String>{};
      _batchValidation = null;
    });
  }

  Future<void> _batchScheduleDrafts(BuildContext context) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要定时的草稿。')),
      );
      return;
    }
    
    // Validate first
    setState(() {
      _publishBusy = true;
    });
    try {
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      if (!context.mounted) {
        return;
      }
      
      if (validation.blockedCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('批量定时验证'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('就绪：${validation.readyCount} 张草稿'),
                Text('阻塞：${validation.blockedCount} 张草稿'),
                const SizedBox(height: 12),
                const Text('阻塞原因：'),
                ...validation.blockedDrafts.take(5).map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续定时就绪草稿'),
              ),
            ],
          ),
        );
        
        if (proceed != true || !context.mounted) {
          return;
        }
      }
      
      final dt = await _pickScheduleDateTime(context);
      if (dt == null || !context.mounted) {
        return;
      }
      
      final iso = dt.toUtc().toIso8601String();
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        scheduledAtIso: iso,
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!context.mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已批量定时 ${res.updated} 张草稿：$iso（UTC）')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量定时失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量定时失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _batchPublishDrafts() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要发布的草稿。')),
      );
      return;
    }
    
    setState(() {
      _publishBusy = true;
    });
    try {
      // Validate first
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      setState(() {
        _batchValidation = validation;
      });
      
      if (!mounted) {
        return;
      }
      
      if (validation.blockedCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('批量发布验证'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('就绪：${validation.readyCount} 张草稿'),
                Text('阻塞：${validation.blockedCount} 张草稿'),
                const SizedBox(height: 12),
                const Text('阻塞原因：'),
                ...validation.blockedDrafts.take(5).map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续发布就绪草稿'),
              ),
            ],
          ),
        );
        
        if (proceed != true || !mounted) {
          return;
        }
      }
      
      final res = await batchPublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        immediate: true,
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量发布完成：成功 ${res.successCount}，失败 ${res.failedCount}')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量发布失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量发布失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _batchArchiveDrafts() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要归档的草稿。')),
      );
      return;
    }
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量归档确认'),
        content: Text('确定要归档 ${_selectedDraftIds.length} 张草稿吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认归档'),
          ),
        ],
      ),
    );
    
    if (proceed != true || !mounted) {
      return;
    }
    
    setState(() {
      _publishBusy = true;
    });
    try {
      final res = await batchArchivePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已归档 ${res.archivedCount} 张草稿')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量归档失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量归档失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  void _compareDrafts() {
    if (_selectedDraftIds.length < 2 || _selectedDraftIds.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择 2-4 张草稿进行对比。')),
      );
      return;
    }
    
    // TODO: Implement draft comparison view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('草稿对比功能：已选择 ${_selectedDraftIds.length} 张草稿')),
    );
  }

  // P11: Delivery mode handlers
  void _onDeliveryModeFilterChanged(String mode) {
    setState(() {
      _deliveryModeFilter = mode == _deliveryModeFilter ? null : mode;
    });
  }
}
