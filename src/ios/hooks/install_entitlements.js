// using error to see if this shows up in AB
console.error("Running hook to add iCloud entitlements");

var fs = require('fs'),
    path = require('path');

    var getPreferenceValue = function(config, name) {
      var value = config.match(new RegExp('name="' + name + '" value="(.*?)"', "i"))
      if(value && value[1]) {
          return value[1]
      } else {
          return null
      }
  }

module.exports = function (context) {
  var xcode = require('xcode');
  var Q = require('q');
  var deferral = new Q.defer();

  if (context.opts.cordova.platforms.indexOf('ios') < 0) {
    throw new Error('This plugin expects the ios platform to exist.');
  }

  var iosFolder = context.opts.cordova.project ? context.opts.cordova.project.root : path.join(context.opts.projectRoot, 'platforms/ios/');
  console.error("iosFolder: " + iosFolder);

  fs.readdir(iosFolder, function (err, data) {
    if (err) {
      throw err;
    }

    var projFolder;
    var projName;

    // Find the project folder by looking for *.xcodeproj
    if (data && data.length) {
      data.forEach(function (folder) {
        if (folder.match(/\.xcodeproj$/)) {
          projFolder = path.join(iosFolder, folder);
          projName = path.basename(folder, '.xcodeproj');
        }
      });
    }

    if (!projFolder || !projName) {
      throw new Error("Could not find an .xcodeproj folder in: " + iosFolder);
    }
    console.error("projFolder: " + projFolder);
    console.error("projName: " + projName);

    var destFile = path.join(iosFolder, projName, 'Resources', projName + '.entitlements');
    console.error("Project entitlement destFile: " + destFile);
    if (fs.existsSync(destFile)) {
      console.error("File exists, not doing anything: " + destFile);
    } else {
      var sourceFile = path.join(context.opts.plugin.pluginInfo.dir, 'src/ios/resources/iCloud.entitlements');
      console.error("icloud entitlement file: " + sourceFile);
      fs.readFile(sourceFile, 'utf8', function (err, data) {

        if(process.argv.join("|").indexOf("CONTAINER_NAME=") > -1) {
          var CONTAINER_NAME = process.argv.join("|").match(/CONTAINER_NAME=(.*?)(\||$)/)[1]
        } else {
          var config = fs.readFileSync("config.xml").toString()
          var CONTAINER_NAME = getPreferenceValue(config, "CONTAINER_NAME")
        }
        console.error("CONTAINER_NAME: " + CONTAINER_NAME);
        data.replace(/CONTAINER_NAME/g, CONTAINER_NAME)


        var resourcesFolderPath = path.join(iosFolder, projName, 'Resources');
        fs.existsSync(resourcesFolderPath) || fs.mkdirSync(resourcesFolderPath);
        fs.writeFileSync(destFile, data);
        console.error('wrote  ' + sourceFile + ' to ' + destFile);
        var projectPath = path.join(projFolder, 'project.pbxproj');

        var pbxProject;
        if (context.opts.cordova.project) {
          pbxProject = context.opts.cordova.project.parseProjectFile(context.opts.projectRoot).xcode;
        } else {
          console.error('use node module xcode');
          pbxProject = xcode.project(projectPath);
          pbxProject.parseSync();
        }

        pbxProject.addResourceFile(projName + ".entitlements");

        var configGroups = pbxProject.hash.project.objects['XCBuildConfiguration'];
        for (var key in configGroups) {
          var config = configGroups[key];
          if (config.buildSettings !== undefined) {
            config.buildSettings.CODE_SIGN_ENTITLEMENTS = '"' + projName + '/Resources/' + projName + '.entitlements"';
          }
        }

        // write the updated project file
        fs.writeFileSync(projectPath, pbxProject.writeSync());
        console.error("Added iCloud entitlements to project '" + projName + "'");

        deferral.resolve();
      });
    }
  });

  return deferral.promise;
};
