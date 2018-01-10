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
var classTest = require('./testClasses');
var globalTest = require('./testGlobal');
RunTest(globalTest);
RunTest(classTest);
Event = function (sender) {
  console.log('event should be called after end of test');
  console.log(`event sender = ${sender}`);
}
console.log('End test file\n' +
            `  summary test count: ${testCount}\n` + 
            `  passed test count:  ${passedCount}\n`);
