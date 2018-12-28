program Test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Math,
  NodeInterface in 'src\NodeInterface.pas',
  NodeEngine in 'src\NodeEngine.pas',
  TestClasses in 'src\TestClasses.pas',
  EngineHelper in 'src\EngineHelper.pas',
  TestRecords in 'src\TestRecords.pas',
  TestInterfaces in 'src\TestInterfaces.pas',
  TestHelpers in 'src\TestHelpers.pas',
  ScriptAttributes in 'src\ScriptAttributes.pas';

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
  {$IFDEF DEBUG}
    ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    Engine := TJSEngine.Create;
    Global := TTestGlobal.Create;
    try
      Engine.AddGlobal(Global);
      // there should be 2 additional params for debugging test
      // 1. --inspect-brk
      // 2. script path (for test should be the same as without debugging)
      if ParamCount = 2 then
      begin
        Engine.AddAdditionalArgument(ParamStr(1));
        Engine.RunFile(ParamStr(2));
      end
      else
        Engine.RunFile('../embed/delphi/test/test.js');
      Engine.CallFunction('StartTest');
      Engine.CheckEventLoop; //check if event timer call callback
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
