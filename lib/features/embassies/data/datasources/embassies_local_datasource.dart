import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/embassy_model.dart';

const String cachedEmbassies = 'CACHED_EMBASSIES';

class EmbassiesLocalDataSource {
  Future<void> cacheEmbassies(List<EmbassyModel> embassies) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final jsonList = embassies.map((e) => e.toJson()).toList();
    await sharedPreferences.setString(cachedEmbassies, jsonEncode(jsonList));
  }

  Future<List<EmbassyModel>> getLastEmbassies() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final jsonString = sharedPreferences.getString(cachedEmbassies);

    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => EmbassyModel.fromJson(e)).toList();
    } else {
      throw CacheException('No cached embassies found');
    }
  }
}
