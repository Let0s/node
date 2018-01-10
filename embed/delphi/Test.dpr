program Test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Math,
  NodeInterface in 'src\NodeInterface.pas',
  NodeEngine in 'src\NodeEngine.pas',
  TestClasses in 'src\TestClasses.pas',
  EngineHelper in 'src\EngineHelper.pas';

const
  NewLine = #10#13;
{$ifdef DEBUG}
  iter_count = 10000000;
{$endif}
{$ifdef RELEASE}
  iter_count = 1000000000;
{$endif}

var
  Engine: TJSEngine;
  Global: TTestGlobal;
begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    InitNode(StringToPUtf8Char(ParamStr(0)));
    Engine := TJSEngine.Create;
    Global := TTestGlobal.Create;
    try
      Engine.AddGlobal(Global);
      Engine.RunFile('../embed/delphi/test/test.js');
      Engine.CheckEventLoop; //wait for global timer
      ReadLn;
      if Assigned(Global.Event) then
        Global.Event(Global);
      Engine.CheckEventLoop; //wait for event timer
      Readln;
    finally
      Global.Free;
      Engine.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
