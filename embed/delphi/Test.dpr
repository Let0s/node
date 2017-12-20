program Test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Math,
  NodeInterface in 'src\NodeInterface.pas';

const
  NewLine = #10#13;
{$ifdef DEBUG}
  iter_count = 10000000;
{$endif}
{$ifdef RELEASE}
  iter_count = 1000000000;
{$endif}

var
  Engine: INodeEngine;
begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    InitNode(StringToPUtf8Char(ParamStr(0)));
    Engine := NewDelphiEngine(nil);
    try
      Engine.RunString(StringToPUtf8Char('' + NewLine
        + 'console.log(''hello, world!'')' + NewLine
        + 'const NS_PER_SEC = 1e9;' + NewLine
        + 'var sum = 0;' + NewLine
        + 'const iter_count = ' + IntToStr(iter_count) + ';' + NewLine
        + 'const time = process.hrtime();' + NewLine
        + 'for (var i = 0; i < iter_count; i ++)'  + NewLine
        + '  sum += i;'  + NewLine
        + 'const diff = process.hrtime(time);' + NewLine
        + 'console.log(`sum = ${sum}`);' + NewLine
        + 'console.log(`this took ${diff[0] * NS_PER_SEC + diff[1]}'
        + ' nanoseconds or about ${diff[0]} seconds`);' + NewLine
        + ''));
    finally
      Engine.Delete;
    end;
    Readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
