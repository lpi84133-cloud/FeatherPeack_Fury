/// Every runtime image, cut from the delivered artwork by `tool/prepare_assets.py`.
abstract final class FpImages {
  static const _dir = 'assets/images';

  // Boot and backdrops
  static const bootPortrait = '$_dir/boot_portrait.jpg';
  static const bootLandscape = '$_dir/boot_landscape.jpg';
  static const mountainBackdrop = '$_dir/mountain_backdrop.jpg';
  static const wordmark = '$_dir/wordmark.webp';

  // Mascot
  static const chickenStanding = '$_dir/chicken_standing.webp';
  static const chickenWalking = '$_dir/chicken_walking.webp';
  static const chickenPacked = '$_dir/chicken_packed.webp';
  static const chickenResting = '$_dir/chicken_resting.webp';

  // Peak — route and difficulty
  static const peakGreen = '$_dir/peak_green.webp';
  static const peakSnow = '$_dir/peak_snow.webp';
  static const peakRock = '$_dir/peak_rock.webp';
  static const peakGolden = '$_dir/peak_golden.webp';

  // Feather — load
  static const featherWhite = '$_dir/feather_white.webp';
  static const featherCream = '$_dir/feather_cream.webp';
  static const featherBrown = '$_dir/feather_brown.webp';
  static const featherGreen = '$_dir/feather_green.webp';

  // Egg — food units
  static const eggSingle = '$_dir/egg_single.webp';
  static const eggPair = '$_dir/egg_pair.webp';
  static const eggLarge = '$_dir/egg_large.webp';
  static const eggGolden = '$_dir/egg_golden.webp';

  // Coin — budget
  static const coinSingle = '$_dir/coin_single.webp';
  static const coinStack = '$_dir/coin_stack.webp';
  static const coinColumn = '$_dir/coin_column.webp';
  static const coinPile = '$_dir/coin_pile.webp';

  // Gear categories
  static const categoryHealth = '$_dir/category_health.webp';
  static const categoryClothing = '$_dir/category_clothing.webp';
  static const categoryElectronics = '$_dir/category_electronics.webp';
  static const categoryFood = '$_dir/category_food.webp';
  static const gearBackpack = '$_dir/gear_backpack.webp';
  static const gearBottle = '$_dir/gear_bottle.webp';
  static const gearCompass = '$_dir/gear_compass.webp';
  static const gearFlashlight = '$_dir/gear_flashlight.webp';

  // Fury zones
  static const furySteepSign = '$_dir/fury_steep_sign.webp';
  static const furyHeavyPack = '$_dir/fury_heavy_pack.webp';
  static const furyLongDuration = '$_dir/fury_long_duration.webp';
  static const furyRockySign = '$_dir/fury_rocky_sign.webp';

  // Terrain
  static const terrainGrass = '$_dir/terrain_grass.webp';
  static const terrainSand = '$_dir/terrain_sand.webp';
  static const terrainRock = '$_dir/terrain_rock.webp';
  static const terrainSnow = '$_dir/terrain_snow.webp';

  // Route markers
  static const markerFlag = '$_dir/marker_flag.webp';
  static const markerAscentSign = '$_dir/marker_ascent_sign.webp';
  static const markerCairn = '$_dir/marker_cairn.webp';
  static const markerSummitPost = '$_dir/marker_summit_post.webp';

  // Weather
  static const weatherSun = '$_dir/weather_sun.webp';
  static const weatherCloud = '$_dir/weather_cloud.webp';
  static const weatherRain = '$_dir/weather_rain.webp';
  static const weatherSnow = '$_dir/weather_snow.webp';
  static const weatherWind = '$_dir/weather_wind.webp';
  static const weatherFog = '$_dir/weather_fog.webp';
  static const weatherStorm = '$_dir/weather_storm.webp';
  static const weatherPartly = '$_dir/weather_partly.webp';

  // Empty states
  static const emptyNewTrip = '$_dir/empty_new_trip.webp';
  static const emptyNoRouteData = '$_dir/empty_no_route_data.webp';
  static const emptyNoSavedTrips = '$_dir/empty_no_saved_trips.webp';

  /// Images worth warming up during boot so the first paint of the dashboard is
  /// not spent decoding. Ordered by how early the user sees them.
  static const precacheList = <String>[
    mountainBackdrop,
    wordmark,
    chickenPacked,
    peakGreen,
    featherGreen,
    eggSingle,
    coinStack,
    emptyNewTrip,
    emptyNoSavedTrips,
  ];
}
