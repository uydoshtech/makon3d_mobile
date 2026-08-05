import "package:flutter_test/flutter_test.dart";

import "package:makon3d_mobile/models/makon_user_role.dart";

void main() {
  test("parses supported Makon roles from API values", () {
    expect(MakonUserRole.fromApi("customer"), MakonUserRole.customer);
    expect(MakonUserRole.fromApi(" CONTRACTOR "), MakonUserRole.contractor);
    expect(MakonUserRole.fromApi("supplier"), MakonUserRole.supplier);
  });

  test("rejects missing and unsupported Makon roles", () {
    expect(MakonUserRole.fromApi(null), isNull);
    expect(MakonUserRole.fromApi("tenant"), isNull);
    expect(MakonUserRole.fromApi(1), isNull);
  });
}
