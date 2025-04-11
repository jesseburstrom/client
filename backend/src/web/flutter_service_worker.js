'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "fe014c7b1b1b65908b523cf83e9a334d",
"assets/AssetManifest.bin.json": "2e67d66753e9a7ae59b07feb32657b43",
"assets/AssetManifest.json": "9ba92a01cb3a9ec3e586e72bf2ebd10c",
"assets/assets/audio/blipp.mp3": "e16e087215b6c28ac705245108cb5f39",
"assets/assets/audio/harp.mp3": "8dca853cd507864bf21eda05d3ef36ce",
"assets/assets/audio/kliiing.mp3": "9fb403f6d2fe7cd6fb2c8f6f35d838d3",
"assets/assets/audio/light_pling.mp3": "f2be6e17211692e5c1f8d60eeeeb0e44",
"assets/assets/audio/pling.mp3": "82b4832707a8b11291eb86046a056718",
"assets/assets/audio/thud.mp3": "3584765a7ffa9f4498e74a0470453387",
"assets/assets/blipp.mp3": "e16e087215b6c28ac705245108cb5f39",
"assets/assets/images/1.jpg": "7421347a8b7a18eba3d104f7bc68b757",
"assets/assets/images/2.jpg": "ca2543cf6f65d0a94f90de932f53d891",
"assets/assets/images/3.jpg": "81ff0aba33134474ed80170749ad70b8",
"assets/assets/images/4.jpg": "b32f838e7920ad14518e5d4e1afcf722",
"assets/assets/images/5.jpg": "0509929c8170e196fc265cc51b179ec3",
"assets/assets/images/6.jpg": "a1a14eea0b1fe3b1779943d43a22f06e",
"assets/assets/images/arrowBottom.png": "3c251d9063321b63b3e447d207f750c9",
"assets/assets/images/arrowLeft.png": "ba6507d628d890b8aaa407e86444d60b",
"assets/assets/images/arrowRight.png": "c7a5719b58c27fb32405bbf42d41b201",
"assets/assets/images/arrowTop.png": "3c6f6d6e328741c9ae945e680679e9e2",
"assets/assets/images/background.jpg": "3d88f6382a18e1b877901ed0575b2600",
"assets/assets/images/bk/banner.jpg": "4ac06c65e5ebba22aacfbbb567acfc7b",
"assets/assets/images/bk/campaign.jpg": "caf7ab13a5c6816e5f64041018d237a9",
"assets/assets/images/bk/desserts.jpg": "cf899278ffe14fe7b0905fcd7397c703",
"assets/assets/images/bk/drinks.jpg": "134f6812e2aa89c528c3c06738e9ea69",
"assets/assets/images/bk/green.jpg": "c4691434a23336510f94884d38d7a7d6",
"assets/assets/images/bk/kingjr.jpg": "89590c10ea0b27835d3b7428c317c0a4",
"assets/assets/images/bk/meals.jpg": "381c89f40a9ccf15376ba35865a5cceb",
"assets/assets/images/bk/singles.jpg": "f1b30b5e2e14b544ed30bc7c5b82730a",
"assets/assets/images/bk/snacks.jpg": "885df5716162cd1a95b4e1c2997617b9",
"assets/assets/images/empty.jpg": "e5ac068b9d05e367fb8458efbb32698a",
"assets/assets/images/flutter_logo.png": "cc8878834b02681c9915c7c7e8eeb00f",
"assets/assets/images/hold.jpg": "3bd7808f169d97f1e42f9c1ccb726518",
"assets/assets/images/img1.jpg": "f9af004239424c89617f8fb410d5d750",
"assets/assets/images/img2.jpg": "a57f6ab554d9fcdaa7e108be7b960bf3",
"assets/assets/images/img3.jpg": "574baa69808effa5022f1dcc6561cf40",
"assets/assets/images/neutral.jpg": "0b84fd5f50415582766ac700f346f5a9",
"assets/assets/images/roll.jpg": "20cb0a676bbb89954bfcf88c7b333d8f",
"assets/assets/images/yatzy_landscape.jpg": "66a22ddaaf89276410edbff567eb456f",
"assets/assets/images/yatzy_landscape2.jpg": "ec1590b5d6fe6dff4c91c4081615ffdd",
"assets/assets/images/yatzy_portrait.jpg": "abae29668ba79493fe6782ff9cd016ae",
"assets/assets/images/yatzy_portrait_dark.jpg": "3ad79e072176c3a6284bf94c27cafae7",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "3bda08af5feef6b9e0642d8106b2e379",
"assets/NOTICES": "98950d12e4a5552e7960d63abbedc641",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "65427ea26f50b0a8fca83cc146d77afb",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "837b46253924d99c2cb0cc7524add0d8",
"/": "837b46253924d99c2cb0cc7524add0d8",
"main.dart.js": "720d80312b958c3f634a40527efeb761",
"manifest.json": "b9d3324652eb9987dc1140f15e318777",
"UnityLibrary/Build/UnityLibrary.data": "d8bfe330f57015d1115797aa714555dc",
"UnityLibrary/Build/UnityLibrary.framework.js": "9a6d977f82f0a80465064b29c86ef92e",
"UnityLibrary/Build/UnityLibrary.loader.js": "d0a081846df94a245bc557ddbc5cb565",
"UnityLibrary/Build/UnityLibrary.wasm": "6d285d7a8bfa03378113f358c1edcf89",
"UnityLibrary/index.html": "70f3d5818b702b50722ec0258e88f27f",
"UnityLibrary/TemplateData/favicon.ico": "f04ae07ad1b634a4152d2c8175134c56",
"UnityLibrary/TemplateData/fullscreen-button.png": "489a5a9723567d8368c9810cde3dc098",
"UnityLibrary/TemplateData/MemoryProfiler.png": "90178b1c01bd4c66a21b9f2866091783",
"UnityLibrary/TemplateData/progress-bar-empty-dark.png": "781ae0583f8c2398925ecedfa04b62df",
"UnityLibrary/TemplateData/progress-bar-empty-light.png": "4412cb4b67a2ae33b3e99cccf8da54c9",
"UnityLibrary/TemplateData/progress-bar-full-dark.png": "99949a10dbeffcdf39821336aa11b3e0",
"UnityLibrary/TemplateData/progress-bar-full-light.png": "9524d4bf7c6e05b2aa33d1a330491b24",
"UnityLibrary/TemplateData/style.css": "a98426604ae4222d09cc97a165cca3f2",
"UnityLibrary/TemplateData/unity-logo-dark.png": "5f00fa907e7c80061485fc64b62ca192",
"UnityLibrary/TemplateData/unity-logo-light.png": "daf8545f18a102b4fa8f693681c2ffe0",
"UnityLibrary/TemplateData/unity-logo-title-footer.png": "1ecf1ff2683fbcd4e4525adb1d2cd7a8",
"UnityLibrary/TemplateData/webmemd-icon.png": "e409a6f1c955c2babb36cd2153d418b5",
"version.json": "039712324ed54ec8013626b3bca85703"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
