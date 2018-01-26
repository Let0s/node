var fs = require('fs');
var path = require('path');
var testCount = 0;
var passedCount = 0;

function RunTest(testObj){
  for (key in testObj) {
    if (typeof testObj[key] == 'function') {
      console.log('---------------------');
      console.log('run ' + key + ' test.');
      testCount++;
      if (testObj[key]()) {
        console.log('test ' + key + ' success.');
        passedCount++;
      }
      console.log('---------------------\n');
    }
  }  
}

console.log('start test file');

var files = fs.readdirSync('./');

for (var i = 0; i < files.length; i++){
  try{
    var test = require(`./${files[i]}`);
    RunTest(test);
  }
  catch (e){
    console.log(e);
  }
}

console.log('End test file\n' +
            `  summary test count: ${testCount}\n` + 
            `  passed test count:  ${passedCount}\n`);
