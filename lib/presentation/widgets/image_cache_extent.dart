import 'package:flutter/widgets.dart';

/// Decode width for a square `BoxFit.cover` thumbnail of [logical] size.
///
/// Only the width is fixed so the aspect ratio survives; the 2× headroom keeps
/// landscape photos up to 2:1 sharp after cover-cropping, while a 4000 px
/// product photo still decodes to ~250 px instead of filling the raster cache.
int thumbCacheExtent(BuildContext context, double logical) =>
    imageCacheWidth(MediaQuery.devicePixelRatioOf(context), logical * 2);

/// Physical pixels for [logical] width at [devicePixelRatio], at least 1.
int imageCacheWidth(double devicePixelRatio, double logical) =>
    (logical * devicePixelRatio).ceil().clamp(1, 1 << 14);
