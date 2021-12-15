import 'dart:convert';

import 'dart:io';

import 'package:ads_mediation_setup/models/app_lovin.dart';
import 'package:ads_mediation_setup/models/google.dart';
import 'package:ads_mediation_setup/models/tag.dart';
import 'package:xml/xml.dart';

import 'file_utils.dart';

class AndroidSetup {
  final String PATH_MANIFEST = 'android/app/src/main/AndroidManifest.xml';
  final String APP_LEVEL_GRADLE = 'android/app/build.gradle';
  final String PLIST_PATH = 'ios/Runner/Info.plist';
  final String jsonFilePath;
  late AppLovin _appLovin;
  late Google _google;

  final String APPLICATION_ID = """\n        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="APPLICATION_ID_HERE"/>""";
  final String APPLOVIN_SDK_KEY = """<meta-data
            android:name="applovin.sdk.key"
            android:value="APPLOVIN_SDK_KEY_HERE" />""";

  AndroidSetup(this.jsonFilePath);
  Future<void> process() async {
    if (await fileExists(jsonFilePath)) {
      _loadObjects(jsonFilePath);
      _platformSpecificSetup();
    } else {
      print('The json file you provided doesnt exists!');
    }
  }

  // IOS : Function to update the info.plist file (adding mediation setup)
  _iosInfoPlistUpdate() async {
    // Reading Info.plist contents from file
    String plistData = await File(PLIST_PATH).readAsString();
    // Creating xml object
    final document = XmlDocument.parse(plistData);
    // Extracting the keys from the Info.plist file which is at <plist><dict>(all keys are here)</dict></plist>
    var keys = document
        .findElements('plist')
        .first
        .findElements('dict')
        .first
        .children;
    // Removing xml elements which are generated due to line breaks (this xml parser is creating xml element as 'XmlText' for line breaks)
    keys.removeWhere((element) => element is XmlText);

    // Flags to know whether the configuration of any of the following already exists in Info.plist
    bool _googleConfigured = false;
    bool _appLovinConfigured = false;

    for (int i = 0; i < keys.length; i++) {
      // Will be true if google is already configured
      if (keys[i].innerText == 'GADApplicationIdentifier') {
        var value = XmlElement(XmlName('string'));
        value.innerText = _google.appId;
        keys.removeAt(i + 1);
        keys.insert(i + 1, value);
        _googleConfigured = true;
      }
      // Will be true if appLovin is already configured
      if (keys[i].innerText == 'AppLovinSdkKey') {
        var value = XmlElement(XmlName('string'));
        value.innerText = _appLovin.sdkKey;
        keys.removeAt(i + 1);
        keys.insert(i + 1, value);
        _appLovinConfigured = true;
      }
    }

    // Will be true when google is not already configured
    if (!_googleConfigured) {
      var key = XmlElement(XmlName('key'));
      key.innerText = 'GADApplicationIdentifier';
      var value = XmlElement(XmlName('string'));
      value.innerText = _google.appId;
      keys.insert(0, value);
      keys.insert(0, key);
    }
    // Will be true when appLovin is not already configured
    if (!_appLovinConfigured) {
      var key = XmlElement(XmlName('key'));
      key.innerText = 'AppLovinSdkKey';

      var value = XmlElement(XmlName('string'));
      value.innerText = _appLovin.sdkKey;
      keys.insert(0, value);
      keys.insert(0, key);
    }

    // Prettifying (formatting) updated Info.plist data
    String updatedPlistData = document.toXmlString(pretty: true, indent: '\t');
    // Saving the updated Info.plist data
    await _saveFile(PLIST_PATH, updatedPlistData);
  }

  // Android : Function to update the AndroidManifest.xml file (adding mediation setup)
  _androidManifestUpdate() async {
    String manifestData = await File(PATH_MANIFEST).readAsString();
    final document = XmlDocument.parse(manifestData);
    List<XmlElement> metadatas = document.children.first
        .findAllElements('application')
        .first
        .findElements('meta-data')
        .toList();
    var application =
        document.children.first.findAllElements('application').first.children;

    bool _googleConfigured = false;
    bool _appLovinConfigured = false;

    metadatas.forEach((element) {
      if (element.attributes[0].value ==
          'com.google.android.gms.ads.APPLICATION_ID') {
        application.remove(element);
        element.attributes[1].value = _google.appId;
        application.insert(0, element);
        _googleConfigured = true;
      }
      if (element.attributes[0].value == 'applovin.sdk.key') {
        element.attributes[1].value = _appLovin.sdkKey;
        application.remove(element);
        application.insert(0, element);
        _appLovinConfigured = true;
      }
    });

    if (!_googleConfigured) {
      var nameAttr = XmlAttribute(
          XmlName('android:name'), 'com.google.android.gms.ads.APPLICATION_ID');
      var valueAttr =
          XmlAttribute(XmlName('android:value'), '${_google.appId}');
      application.insert(
          0, XmlElement(XmlName('meta-data'), [nameAttr, valueAttr]));
    }

    if (!_appLovinConfigured) {
      var nameAttr = XmlAttribute(XmlName('android:name'), 'applovin.sdk.key');
      var valueAttr =
          XmlAttribute(XmlName('android:value'), '${_appLovin.sdkKey}');
      application.insert(
          0, XmlElement(XmlName('meta-data'), [nameAttr, valueAttr]));
    }

    String updatedManifestData =
        document.toXmlString(pretty: true, indent: '\t');
    await _saveFile(PATH_MANIFEST, updatedManifestData);
  }

  // Android : Function to update the app level build.gradle file (add sdk dependencies)
  _buildGradleUpdate() async {
    String gradleData = await File(APP_LEVEL_GRADLE).readAsString();
    String dependenciesBlock = RegExp(r'((dependencies)\s*(\{))(.|\n)*\}')
        .firstMatch(gradleData)!
        .group(0)!;

    List<String> dependencies = RegExp(r'\{([^}]+)\}')
        .firstMatch(dependenciesBlock)!
        .group(0)!
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split('\n');
    dependencies.removeWhere((element) => element == '');
    dependencies =
        _addDependency(dependencies, _google.sdk, _google.sdkVersion);

    dependencies =
        _addDependency(dependencies, _appLovin.sdk, _appLovin.sdkVersion);
    var str = dependencies.join('\n');
    String updatedDependenciesBlock = "dependencies {\n$str\n}";

    gradleData =
        gradleData.replaceAll(dependenciesBlock, updatedDependenciesBlock);
    await File(APP_LEVEL_GRADLE).writeAsString(gradleData);
  }

  // Function to add sdk implementation in build.gradle file
  _addDependency(List<String> dependencies, String depPath, String depVersion) {
    List<String> result = [];
    bool alreadyExists = false;
    dependencies.forEach((dependency) {
      String toAdd = '';
      if (dependency.contains(depPath)) {
        toAdd = "implementation \"$depPath:$depVersion\"";
        alreadyExists = true;
      } else {
        toAdd = dependency.trim();
      }
      result.add(toAdd);
    });
    if (!alreadyExists) {
      result.add("implementation \"$depPath:$depVersion\"");
    }

    return result;
  }

  _platformSpecificSetup() async {
    // _androidManifestUpdate();
    // _buildGradleUpdate();
    _iosInfoPlistUpdate();
  }

  _loadObjects(String filePath) async {
    String jsonAsString = await File(filePath).readAsString();
    var decodedJsonFile = json.decode(jsonAsString) as Map<String, dynamic>;
    _appLovin = AppLovin.fromJson(decodedJsonFile['AppLovin']);
    _google = Google.fromJson(decodedJsonFile['Google']);

    print(_appLovin.toJson());
    print(_google.toJson());
  }

  Future<File> _saveManifestFile(String fileData) async {
    return await File(PATH_MANIFEST).writeAsString(fileData);
  }

  Future<File> _saveFile(String filePath, String data) async {
    return await File(filePath).writeAsString(data);
  }
}
