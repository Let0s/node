unit TestRecords;

interface

uses
  Math;

type
  TTestPoint = record
  public
    x: double;
    y: double;
    constructor Create(ax, ay: double);
    function Length: double;
  end;

implementation

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
