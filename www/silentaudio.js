
var exec    = require('cordova/exec'),
    channel = require('cordova/channel');

module.exports = {    

    play: function (successCallback, errorCallback, duration, volumeOverride) {
        cordova.exec(successCallback, errorCallback, 'SilentAudio', 'play', [duration, volumeOverride]);        
    }
}
