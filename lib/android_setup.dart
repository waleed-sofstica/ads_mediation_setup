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

  _platformSpecificSetup() async {
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
    await _saveManifestFile(updatedManifestData);

    String gradleData = await File(APP_LEVEL_GRADLE).readAsString();
    var match = RegExp('dependencies+.*').firstMatch(gradleData);
    String dep = match!.group(0)!;
    int index = gradleData.indexOf(dep);
    int index2 = gradleData.indexOf('}', index);
    String dependencies = gradleData.substring(index, index2);
    List<String> finalDependenceis = [];
    dependencies.split('\n').forEach((element) {
      element = element.trim();
      if (element != '' &&
          (!element.contains(_appLovin.sdk) || !element.contains(_google.sdk)))
        finalDependenceis.add(element);
    });
    finalDependenceis
        .add("\nimplementation \"${_appLovin.sdk}:${_appLovin.sdkVersion}\"");
    finalDependenceis
        .add("\nimplementation \"${_google.sdk}:${_google.sdkVersion}\"");
    gradleData =
        gradleData.replaceAll(dependencies, 'flag-to-add-new-dependencies');

    String finalDepString = '';
    finalDependenceis.forEach((element) {
      finalDepString += element + '\n';
    });
    gradleData =
        gradleData.replaceAll('flag-to-add-new-dependencies', finalDepString);
    await File(APP_LEVEL_GRADLE).writeAsString(gradleData);
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
}
