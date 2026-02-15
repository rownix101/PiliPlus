import 'package:PiliPro/models_new/model_hot_video_item.dart'; // TODO: 迁移到 models_new/
import 'package:PiliPro/models_new/popular/popular_series_one/config.dart';

class PopularSeriesOneData {
  PopularSeriesConfig? config;
  String? reminder;
  List<HotVideoItemModel>? list;

  PopularSeriesOneData({this.config, this.reminder, this.list});

  factory PopularSeriesOneData.fromJson(Map<String, dynamic> json) =>
      PopularSeriesOneData(
        config: json['config'] == null
            ? null
            : PopularSeriesConfig.fromJson(
                json['config'] as Map<String, dynamic>,
              ),
        reminder: json['reminder'] as String?,
        list: (json['list'] as List<dynamic>?)
            ?.map((e) => HotVideoItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
