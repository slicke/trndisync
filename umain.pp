unit umain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, uInsulinData, uImport, typinfo, opensslsockets, fphttpclient, sha1, LCLType;

type
  TfMain = class(TForm)
    odCSV:TOpenDialog;
    procedure FormCreate(Sender:TObject);
  private
    FRows: TInsulinData;

  public

  end;

var
  fMain: TfMain;

implementation

{$R *.lfm}

// Push data to NS
procedure UplloadTreatments(const AUrl, AApiSecret, AJson: string);
  // Generate the SHA1 checksum to use for auth
  function SHA1OfString(const S: string): string;
  var
    Context: TSHA1Context;
    Digest: TSHA1Digest;
    i: Integer;
  begin
    SHA1Init(Context);
    SHA1Update(Context, PChar(S)^, Length(S));
    SHA1Final(Context, Digest);

    Result := '';
    for i := Low(Digest) to High(Digest) do
      Result := Result + IntToHex(Digest[i], 2);
  end;
var
  Client: TFPHTTPClient;
  FullUrl: string;
  ResponseStr: string;
  SecretSha1: string;
begin
  SecretSha1 := SHA1OfString(AApiSecret);

  Client := TFPHTTPClient.Create(nil);
  try
    // Set a higher timeout
    Client.IOTimeout := 30000; // 30 sek

    // Add required headers
    Client.AddHeader('API-SECRET', LowerCase(SecretSha1));
    Client.AddHeader('Accept', 'application/json');
    Client.AddHeader('Content-Type', 'application/json');

    // Build /api/v1/treatments URL
    FullUrl := Aurl;
    if not FullUrl.EndsWith('/') then
       FullUrl += '/';
    FullUrl := FullUrl + 'api/v1/treatments';

    // POST the JSON body
    Client.RequestBody := TRawByteStringStream.Create(AJson);
    ResponseStr := Client.Post(FullUrl);

    // Read response
    if Client.ResponseStatusCode <> 200 then
    begin
      raise Exception.CreateFmt(
        'Nightscout upload error %d: %s',
        [Client.ResponseStatusCode, ResponseStr]
      );
    end;
  finally
    Client.Free;
  end;
end;

procedure TfMain.FormCreate(Sender:TObject);
var
  i: integer;
  io: TInsulinRecord;
begin
// Load the data
fRows := TInsulinData.Create;
if not odCSV.Execute then
   exit;

fRows.LoadFromFile(odCSV.FileName);

// Open a form with the data we parsed
with TfImport.Create(self) do begin
// Show the parsed data. Yes, it's ironic that we convert stuff back to strings!
// However we now know that our data is correctly typed
 for i := 0 to FRows.Count-1 do begin
   io := frows.GetItem(i);
   lvSync.AddItem(IntToStr(i), nil);
   lvSync.Items[i].SubItems.Add(DateTimeToStr(io.Timestamp));
   lvSync.Items[i].SubItems.Add(Copy(GetEnumName(TypeInfo(TInsulinType), ord(io.InsulinType)),3)); // Remove "it"
   lvSync.Items[i].SubItems.Add(FormatFloat('0.0##',io.BloodGlucose));
   lvSync.Items[i].SubItems.Add(FormatFloat('0.0##',io.CarbsInput));
   lvSync.Items[i].SubItems.Add(FormatFloat('0.0##',io.InsulinDeliv));
   lvSync.Items[i].SubItems.Add(FormatFloat('0.0##',io.InitialDeliv));
   lvSync.Items[i].SubItems.Add(FormatFloat('0.0##',io.ExtendedDeliv));
   end;
   ShowModal;
   if ModalResult = mrYes then begin

      UplloadTreatments(InputBox('Enter NightScout URL','Enter your full NightScout URL','') , InputBox('Enter NightScout Secret','Enter your NightScout Secret',''), FRows.GetJSON);
   end;
 Free;
end;
end;

end.

