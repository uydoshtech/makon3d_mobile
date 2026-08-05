enum MakonUserRole {
  customer("customer"),
  contractor("contractor"),
  supplier("supplier");

  const MakonUserRole(this.apiValue);

  final String apiValue;

  static MakonUserRole? fromApi(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    for (final role in values) {
      if (role.apiValue == normalized) return role;
    }
    return null;
  }
}

extension MakonUserRoleL10n on MakonUserRole {
  String get titleL10nKey => switch (this) {
    MakonUserRole.customer => "makon_role_customer_title",
    MakonUserRole.contractor => "makon_role_contractor_title",
    MakonUserRole.supplier => "makon_role_supplier_title",
  };

  String get subtitleL10nKey => switch (this) {
    MakonUserRole.customer => "makon_role_customer_subtitle",
    MakonUserRole.contractor => "makon_role_contractor_subtitle",
    MakonUserRole.supplier => "makon_role_supplier_subtitle",
  };
}
