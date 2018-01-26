unit TestClasses;

interface

uses
  Math;

type
  TTestPoint = record
  public
    x: double;
    y: double;
  private
    constructor Create(ax, ay: double);
    function Length: double;
  end;

  TTestFigure = class
  public
    function GetSquare: double; virtual; abstract;
  end;

  TTestCircle = class(TTestFigure)
  private
    FRadius: double;
    FCenter: TTestPoint;
  public
    constructor Create(CenterPoint: TTestPoint; Radius: double);
    property Center: TTestPoint read FCenter;
    property Radius: double read FRadius;
    function GetSquare: double; override;
  end;

  TTestRectangle = class(TTestFigure)
  private
    FMin: TTestPoint;
    FMax: TTestPoint;
  public
    constructor Create(MinPoint, MaxPoint: TTestPoint);
    property Min: TTestPoint read FMin;
    property Max: TTestPoint read FMax;
    function GetSquare: double; override;
  end;

  TTestGlobal = class(TObject)
  private
  public
    constructor Create;
    destructor Destroy; override;
    function CreateRectangle(StartPoint, EndPoint: TTestPoint): TTestRectangle;
    function CreateCircle(Radius: double): TTestCircle; overload;
//    function CreateCircle(CenterPoint: TTestPoint;
//      Radius: double): TTestCircle; overload;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
end;

function TTestGlobal.CreateCircle(Radius: double): TTestCircle;
begin
  Result := TTestCircle.Create(TTestPoint.Create(0, 0), Radius);
end;

//function TTestGlobal.CreateCircle(CenterPoint: TTestPoint;
//  Radius: double): TTestCircle;
//begin
//  Result := TTestCircle.Create(CenterPoint, Radius);
//end;

function TTestGlobal.CreateRectangle(StartPoint,
  EndPoint: TTestPoint): TTestRectangle;
begin
  Result := TTestRectangle.Create(StartPoint, EndPoint);
end;

destructor TTestGlobal.Destroy;
begin
  inherited;
end;

{ TTestCircle }

constructor TTestCircle.Create(CenterPoint: TTestPoint; Radius: double);
begin
  FRadius := Radius;
  FCenter := CenterPoint;
end;

function TTestCircle.GetSquare: double;
begin
  Result := 2 * FRadius * Pi;
end;

{ TTestRectangle }

constructor TTestRectangle.Create(MinPoint, MaxPoint: TTestPoint);
begin
  FMin := MinPoint;
  FMax := MaxPoint;
end;

function TTestRectangle.GetSquare: double;
begin
  Result := (Abs(FMin.x - FMax.x) + Abs(FMax.y - FMin.y)) * 2;
end;

{ TTestPoint }

constructor TTestPoint.Create(ax, ay: double);
begin
  x := ax;
  y := ay;
end;

function TTestPoint.Length: double;
begin
  Result := Sqrt(x*x + y*y);
end;

end.
