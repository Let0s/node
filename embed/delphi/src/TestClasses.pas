unit TestClasses;

interface

uses
  Classes;

type
  TTestParent = class(TObject)
  private
    Fprop: string;
    procedure Setprop(const Value: string);
  public
    constructor Create; virtual;
    property prop: string read Fprop write Setprop;
    class function show(): string; virtual;
  end;

  TTestChild = class(TTestParent)
  private
    FChildProp: string;
    procedure SetchildProp(const Value: string);
  public
    constructor Create; override;
    property childProp: string read FchildProp write SetchildProp;
    class function show(): string; override;
  end;

  TTestGlobal = class(TObject)
  private
    FProp: string;
    FEvent: TNotifyEvent;
    Fobj: TTestChild;
    FArray: TArray<Integer>;
    procedure Setobj(const Value: TTestChild);
  public
    constructor Create;
    destructor Destroy; override;
    function Func(argument: string): string;
    property Prop: string read FProp write FProp;
    property Event: TNotifyEvent read FEvent write FEvent;
    property obj: TTestChild read Fobj write Setobj;
    property arr: TArray<Integer> read FArray;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  FProp := 'TTestGlobal.Prop property';
  Fobj := TTestChild.Create;
  FEvent := nil;
  SetLength(FArray, 3);
  FArray[0] := 23;
  FArray[1] := 22;
  FArray[2] := 21;
end;

destructor TTestGlobal.Destroy;
begin
  Fobj.Free;
  inherited;
end;

function TTestGlobal.Func(argument: string): string;
begin
  Result := 'Function TTestGlobal.Func called. argument = ' + argument;
end;

procedure TTestGlobal.Setobj(const Value: TTestChild);
begin
  Fobj := Value;
end;

{ TTestParent }

constructor TTestParent.Create;
begin
  Fprop := 'TTestParent.prop property';
end;

procedure TTestParent.Setprop(const Value: string);
begin
  Fprop := Value;
end;

class function TTestParent.show: string;
begin
  Result := 'TTestParent show';
end;

{ TTestChild }

constructor TTestChild.Create;
begin
  inherited;
  FChildProp := 'TTestChild.childProp property';
end;

procedure TTestChild.SetchildProp(const Value: string);
begin
  FchildProp := Value;
end;

class function TTestChild.show: string;
begin
  Result := 'TTestChild show';
end;

end.
