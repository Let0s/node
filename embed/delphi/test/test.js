console.log('start test file');
console.log(Func('hello'));
console.log(Prop);
console.log(Prop = 'property Prop was modified');
var objec = obj;
console.log(obj.prop);
Event = function(sender){
  console.log('event should be called after "success" log message');
  console.log(`event sender = ${sender}`);
}
console.log('success');