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
  end;

  TTestChild = class(TTestParent)
  private
    FChildProp: string;
    procedure SetchildProp(const Value: string);
  public
    constructor Create; override;
    property childProp: string read FchildProp write SetchildProp;
  end;

  TTestGlobal = class(TObject)
  private
    FProp: string;
    FEvent: TNotifyEvent;
    Fobj: TTestChild;
    procedure Setobj(const Value: TTestChild);
  public
    constructor Create;
    destructor Destroy; override;
    function Func(argument: string): string;
    property Prop: string read FProp write FProp;
    property Event: TNotifyEvent read FEvent write FEvent;
    property obj: TTestChild read Fobj write Setobj;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  FProp := 'TTestGlobal.Prop property';
  Fobj := TTestChild.Create;
  FEvent := nil;
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

end.
