var fs = require('fs');
var path = require('path');
var testCount = 0;
var passedCount = 0;
var fullLog = '';

function RunTest(testObj) {
  for (var key in testObj) {
    if (typeof testObj[key] == 'function') {
      console.log('---------------------');
      console.log('run ' + key + ' test.');
      testCount++;
      try {
        testObj[key]()
        console.log('test ' + key + ' success.');
        passedCount++;
      }
      catch (e) {
        console.log(e.message)
        fullLog += `${e.message}\n${e.stack}\n`;
      }
      console.log('---------------------\n\n');
    }
  }
}
StartTest = function(){
  console.log('start test file');

  var files = fs.readdirSync('./');
  for (var i = 0; i < files.length; i++) {
    try {
      if (path.extname(files[i]).toLowerCase() === '.js') {
        console.log('%s\x1b[33m%s\x1b[0m', 'start test file ', files[i]);
        var test = require(`./${files[i]}`);
        RunTest(test);
      }
    }
    catch (e) {
      console.log(e);
    }
  }
  console.log('End test file\n' +
    `  summary test count: ${testCount}\n` +
    `  passed test count:  ${passedCount}\n`);
  if (fullLog){
    fs.writeFileSync('test.log', fullLog);
    console.log('full error log is in "test.log" file');
  }
}