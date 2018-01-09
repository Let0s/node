console.log('start test file');
console.log(Func('hello'));
console.log(Prop);
console.log(Prop = 'property Prop was modified');
console.log(obj.prop);
console.log(obj.childProp);
console.log(TTestParent.prototype.show());
console.log(TTestChild.prototype.show());
console.log(obj.show());
console.log(`obj is TTestParent = ${obj instanceof TTestParent}`);
console.log(`obj is TTestChild = ${obj instanceof TTestChild}`);
Event = function(sender){
  console.log('event should be called after "success" log message');
  console.log(`event sender = ${sender}`);
}
console.log('success');
