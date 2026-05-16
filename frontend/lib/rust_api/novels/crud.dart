// Backward-compatible novels CRUD surface.
//
// Historical imports may reference `rust_api/novels/crud.dart` directly.
// Re-export canonical REST CRUD functions so those imports keep working.
export 'rest_api.dart'
    show
        createProjectNovelUnderProject,
        deleteProjectNovelByProjectIds,
        fetchProjectNovelByProjectIds,
        fetchProjectNovelsByProjectId,
        patchProjectNovelByProjectIds;
