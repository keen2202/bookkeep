class RepositoryException implements Exception {
  RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 账户仍被流水引用，禁止删除（Spec §3.2 软删除约束）
class AccountInUseException extends RepositoryException {
  AccountInUseException()
      : super('该账户仍有关联流水，不能删除，请改为归档');
}

/// 分类仍被流水引用，禁止删除（Spec §3.3 软删除约束）
class CategoryInUseException extends RepositoryException {
  CategoryInUseException()
      : super('该分类仍被流水使用，不能删除（历史流水将保留原分类名）');
}

/// 分类包含未删除的子分类，需先处理子分类（防止删除父级后子分类失联）
class CategoryHasChildrenException extends RepositoryException {
  CategoryHasChildrenException() : super('该分类包含子分类，请先删除其子分类');
}
