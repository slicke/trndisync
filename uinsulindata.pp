unit uInsulinData;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, csvdocument, DateUtils, fpjson;

type
  // Enum for the field with tye
  TInsulinType = (itNormal, itExtended, itUnknown);

  // Enum for the BG type
  TInsulinUnit = (iuMmol, iuMgdl);

  // A row from the file
  TInsulinRecord = record
    Timestamp:     TDateTime;   // Date/time
    InsulinType:     TInsulinType;
    BloodGlucose:  Single;      // mmol/L or mgdl
    CarbsInput:    Word;
    CarbsRatio:    Single;
    InsulinDeliv:  Single;
    InitialDeliv:  Single;
    ExtendedDeliv: Single;
    SerialNumber:  Cardinal;
  end;

  // The import file
  TInsulinData = class
  private
    FName: string;        // Ex. "John Doe"
    FDateRange: string;   // Ex. "2024-11-14 - 2024-11-27"
    FUnitBG: TInsulinUnit;      // Ex. "mmol/L" = iuMmol
    FData: array of TInsulinRecord;

    function StringToInsulinType(const AStr: string): TInsulinType;
  public
    constructor Create;
    procedure LoadFromFile(const AFileName: string);
    function GetJSON: string;

    function Count: Integer;
    function GetItem(Index: Integer): TInsulinRecord;

    property Name: string read FName;
    property DateRange: string read FDateRange;
    property BGUnit: TInsulinUnit read FUnitBG;
  end;

implementation

{ TInsulinData }

constructor TInsulinData.Create;
begin
  inherited Create;

  // Set default value
  FUnitBG := iuMmol;
end;

// Parse the type
function TInsulinData.StringToInsulinType(const AStr: string): TInsulinType;
begin
  if SameText(AStr, 'Normal') then
    Result := itNormal
  else if SameText(AStr, 'Extended') then
    Result := itExtended
  else
    Result := itUnknown;
end;

// Load the CSV
procedure TInsulinData.LoadFromFile(const AFileName: string);
var
  CSV: TCSVDocument;
  i: Integer;
  // Temp
  TempTimestamp: string;
  TempInsulinType: string;
  TempBloodGlucose: string;
  TempCarbs: string;
  TempCarbsRatio: string;
  TempInsulinDeliv: string;
  TempInitDeliv: string;
  TempExtDeliv: string;
  TempSerial: string;

  // Convert a string to float, with default value
  function StrToSingleDef(const S: string; Default: Single): Single;
  begin
    if S = '' then
      Exit(Default);
    try
      Result := StrToFloat(StringReplace(S, '.', DefaultFormatSettings.DecimalSeparator, []));
    except
      Result := Default;
    end;
  end;

  // Helper for string -> word
  function StrToWordDef(const S: string; Default: Word): Word;
  var
    Value: Integer;
  begin
    if (S = '') then
      Exit(Default);
    try
      Value := StrToInt(StringReplace(S,'.0','',[])); // Eg 0.0 = 0 as this is an integer
      if (Value < 0) or (Value > 65535) then
        Result := Default
      else
        Result := Value;
    except
      Result := Default;
    end;
  end;

  // Helper for date conversion
  function StrToDateTimeDefEx(const S: string; Default: TDateTime): TDateTime;
  begin
    try
      // Try to parse "YYYY-MM-DD hh:mm"
      Result := StrToDateTime(S);
    except
      Result := Default;
    end;
  end;

begin
  CSV := TCSVDocument.Create;
  try
    CSV.Delimiter := ',';
    CSV.LoadFromFile(AFileName);
    // We assume that the first row contains a header
    if CSV.RowCount > 0 then
    begin
      FName := CSV.Cells[0,0];      // Ex: "Name:John Doe"
      FDateRange := CSV.Cells[1,0]; // Ex: "Date Range:2024-11-14 - 2024-11-27"

      // Don't keep the "Name:" prefix:
      if Pos('Name:', FName) = 1 then
        FName := Copy(FName, Length('Name:')+1, Length(FName));

      FName := Trim(FName);

      // Trim the date range prefix
      if Pos('Date Range:', FDateRange) = 1 then
        FDateRange := Copy(FDateRange, Length('Date Range:')+1, Length(FDateRange));
      FDateRange := Trim(FDateRange);
    end;

    // Start processing on row 2
    // RowCount = total row count
    // Assuming columns are
    //  0=Timestamp, 1=Insulin Type, 2=Blood Glucose Input (mmol/l),
    //  3=Carbs Input (g), 4=Carbs Ratio, 5=Insulin Delivered (U),
    //  6=Initial Delivery (U), 7=Extended Delivery (U), 8=Serial Number
    SetLength(FData, 0);
    for i := 2 to CSV.RowCount - 1 do
    begin
      TempTimestamp    := CSV.Cells[0, i];
      TempInsulinType  := CSV.Cells[1, i];
      TempBloodGlucose := CSV.Cells[2, i];
      TempCarbs        := CSV.Cells[3, i];
      TempCarbsRatio   := CSV.Cells[4, i];
      TempInsulinDeliv := CSV.Cells[5, i];
      TempInitDeliv    := CSV.Cells[6, i];
      TempExtDeliv     := CSV.Cells[7, i];
      TempSerial       := CSV.Cells[8, i];

      // Add a slot in the array
      SetLength(FData, Length(FData) + 1);

      with FData[High(FData)] do
      begin
        Timestamp     := StrToDateTimeDefEx(TempTimestamp, 0);
        InsulinType   := StringToInsulinType(TempInsulinType);
        BloodGlucose  := StrToSingleDef(TempBloodGlucose, 0.0);
        CarbsInput    := StrToWordDef(TempCarbs, 0);
        CarbsRatio    := StrToSingleDef(TempCarbsRatio, 0.0);
        InsulinDeliv  := StrToSingleDef(TempInsulinDeliv, 0.0);
        InitialDeliv  := StrToSingleDef(TempInitDeliv, 0.0);
        ExtendedDeliv := StrToSingleDef(TempExtDeliv, 0.0);
        // We use a qword/cardinal here as I have no idea how big a serial can be. Though we don't really case at this point!
        try
          SerialNumber := StrToQWord(TempSerial); // eller StrToIntDef
        except
          SerialNumber := 0;
        end;
      end;
    end;

  finally
    CSV.Free;
  end;
end;

// Return row count
function TInsulinData.Count: Integer;
begin
  Result := Length(FData);
end;

// Fetch a row
function TInsulinData.GetItem(Index: Integer): TInsulinRecord;
begin
  Result := FData[Index];
end;

// Builds JSON for NightScout
function TInsulinData.GetJSON: string;
var
  BolusJSON, Obj: TJSONObject;
  Arr: TJSONArray;
  index: integer;
begin
  Arr := TJSONArray.Create; // Nightscout wants an array of objects

    try
      for index := 0 to Count do begin
      // Create an object in the array
      Obj := TJSONObject.Create;
      Obj.Add('eventType', 'Bolus');
      Obj.Add('enteredBy', 'Trndi');
      Obj.Add('insulin', FData[index].InsulinDeliv);
      // Format the data to fit NS requirements
      Obj.Add('created_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', FData[index].Timestamp));

      if FData[index].InsulinType = itExtended then begin
        Obj.Add('insulinInitial', FData[index].InitialDeliv);
        Obj.Add('insulinExtended', FData[index].ExtendedDeliv);
  //      Obj.Add('duration', FData[index].); // Theres no such data in the CSV?
      end;
      // Append the bolus
      Arr.Add(Obj);
      end;
    result := Arr.AsJSON;
  finally
    Arr.Free;
  end;
end;

end.

