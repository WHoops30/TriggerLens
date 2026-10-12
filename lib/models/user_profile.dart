import 'package:isar/isar.dart';

part 'user_profile.g.dart';

@collection
class UserProfile {
  Id id = Isar
      .autoIncrement; // We will lock this to ID 1 so there is only ever one active profile

  late String phase;
  late double multiplier;
  late int dailyCap;
}
