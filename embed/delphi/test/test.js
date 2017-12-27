console.log('start test file');
console.log(Func());
console.log(Prop);
console.log(Prop = 'property Prop was modified');
Event = function(sender){
  console.log('event should be called after "success" log message');
}
console.log('success');