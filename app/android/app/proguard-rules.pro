# bookkeep release 混淆规则（R8，审查体积 BK-R-015）
# Flutter 应用本体为 AOT 编译，Dart 代码不需要 keep 规则；
# 原生插件经 Flutter 引擎反射注册，一般由插件自带 consumer rules。
# 此处仅保留通用兜底，避免第三方原生库反射被裁剪。

-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
