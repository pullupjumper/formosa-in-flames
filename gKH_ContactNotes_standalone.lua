--[[
--  gKH ContactNotes library functions
--  Filename: ContactNotes.lua
--  Namespace: gKH.ContactNotes
--  Requirement (to use all functions): gKH (namespace, not full library), and gKH.State library.
--  LastModified: tweaked for build 1307.3 bugs with VP_Contact, 02-18-2023
--]]

print("gKH.ContactNotes library loading...");

-- Dependecy Check
if (gKH == nil) or gKH.State == nil then
  local msg =
  "Failed to find required gKH and gKH.State libraries in memory. You need to make sure the scripts that set those up run before this one. ContactNotes script loading aborted.";
  print(msg);
  ScenEdit_MsgBox(msg, 0);
  return;
end

gKH.ContactNotes = {}; --setup namespace
--Initial static defaults
gKH.ContactNotes.SaveKeyName = "gKHContactNotes"
gKH.ContactNotes.ScavengerSide = "Test";
gKH.ContactNotes.ScavengerCycletime = 120;
gKH.ContactNotes.ScavengerNextRuntime = 0;
gKH.ContactNotes.Data = {} --default empty; will be loaded if exists.

-- begin functions --

function gKH.ContactNotes:AddDetectedContact(ct)
  if ct ~= nil then
    local sidename = "Unknown";
    if ct.side ~= nil then sidename = tostring(ct.side.name); end
    self.Data[ct.guid] = {
      note = "None.",
      lastmod = ScenEdit_CurrentTime(),
      lastname = tostring(ct.name),
      side =
          sidename
    };
    gKH.State.SaveTableToKey(self.Data, self.SaveKeyName);
  end
end

function gKH.ContactNotes:AddUpdateNote(sTable)
  if (sTable == nil) or sTable.contacts == nil then
    ScenEdit_MsgBox("Please select at least one contact first.", 0); return;
  end
  for i = 1, #sTable.contacts do
    local retval, ct = pcall(ScenEdit_GetContact, { side = ScenEdit_PlayerSide(), guid = sTable.contacts[i].guid });
    --the following is cause the above call will always return true in SA vs console for some fucked up reason.
    if ((retval == false) or ct == nil) or ct.guid == nil then               --comes back true even on failure, also fails on special group contacts so we try VP, that actually works.
      retval, ct = pcall(VP_GetContact, { guid = sTable.contacts[i].guid }); -- we avoid VP usually because Side will also be available even if unknown.
      if ((retval == false) or ct == nil) or ct.guid == nil then
        ScenEdit_MsgBox(
          "could not obtain contact for guid " ..
          tostring(sTable.contacts[i].guid) ..
          ". Please make sure it's still a valid contact, or you are currently on the correct side in the editor. Call aborted.",
          0);
        return;
      end
    end
    local str = "Enter the new or update note text for contact named " .. ct.name .. ".\r\n";
    if self.Data[ct.guid] ~= nil then
      str = str .. "Existing data:\r\n" .. self.Data[ct.guid].note;
    else
      local sidename = "Unknown";
      if ct.side ~= nil then sidename = tostring(ct.side.name); end
      self.Data[ct.guid] = { note = "", lastname = tostring(ct.name), side = sidename, lastmod = ScenEdit_CurrentTime() };
    end
    local newdata = ScenEdit_InputBox(str);
    if (newdata ~= nil) and newdata ~= "" then
      self.Data[ct.guid].note = newdata;
      gKH.State.SaveTableToKey(self.Data, self.SaveKeyName);
      ScenEdit_MsgBox('Record updated.', 0)
    else
      ScenEdit_MsgBox('Record not updated.', 0)
    end
  end
end

function gKH.ContactNotes:DeleteNote(cguid)
  if self.Data[cguid] ~= nil then
    self.Data[cguid] = nil;
    return true;
  else
    return false; --not found.
  end
end

function gKH.ContactNotes:DeleteSelectedNote(sTable)
  if (sTable == nil) or sTable.contacts == nil then
    ScenEdit_MsgBox("Please select a single contact first.", 0); return;
  end
  --if ((sTable ~= nil) and sTable.contacts ~=nil) and #sTable.contacts > 1 then ScenEdit_MsgBox("Please select only one contact at a time.",0); return; end
  local changeflag = false;
  local multiflag = #sTable.contacts;
  for i = 1, #sTable.contacts do
    local skipit, retval, cname = false, "", tostring(sTable.contacts[i].name);
    if multiflag > 1 then
      retval = ScenEdit_MsgBox("Are you sure you want to delete notes for contact: " .. cname .. "?", 4)
      if retval == "Yes" then skipit = false; else skipit = true; end
    end
    if skipit == false then
      if self:DeleteNote(sTable.contacts[i].guid) then
        changeflag = true;
        ScenEdit_MsgBox("Note record for " .. cname .. " was found and removed.", 0);
      else
        ScenEdit_MsgBox("Note record for " .. cname .. " did not exist yet.", 0);
      end
    end
  end
  if changeflag then
    gKH.State.SaveTableToKey(self.Data, self.SaveKeyName); --resave changes.
  end
end

function gKH.ContactNotes:DeleteAllNotes()
  self.Data = {};
  gKH.State.SaveTableToKey(self.Data, self.SaveKeyName);
end

function gKH.ContactNotes:ShowSelectedContactNotes(su)
  local str = ""
  print(su)
  if (su ~= nil) and su.contacts ~= nil then
    local retval, ct;
    for _, v in ipairs(su.contacts) do
      local isvalid = false;
      retval, ct = pcall(ScenEdit_GetContact, { side = ScenEdit_PlayerSide(), guid == v.guid });
      if (ct ~= nil) and ct.guid ~= nil then
        isvalid = true;
      elseif (ct ~= nil) and ct.guid == nil then
        retval, ct = pcall(VP_GetContact, { guid == v.guid });
        if ct ~= nil and ct.guid ~= nil then
          isvalid = true;
        end
      end
      if self.Data[v.guid] ~= nil then
        str = str ..
            string.format("<P>Contact Name: %s, Side: %s, Notes: %s </P>", self.Data[v.guid].lastname, self.Data[v.guid]
              .side, self.Data[v.guid].note);
      elseif isvalid then
        local sidename = "Unknown";
        if ct.side ~= nil then sidename = tostring(ct.side.name); end
        str = str .. string.format("<P>Contact Name: %s, Side: %s, Notes: %s </P>", v.name, sidename, "None.");
      else
        str = str ..
            string.format("<P>Contact Name: %s ( could not find contact for guid: %s), Side: %s, Notes: %s </P>", v.name,
              v.guid, "Unknown", "None.");
      end
      retval, ct = false, nil;
    end
  else
    ScenEdit_MsgBox("No contacts selected! Please make sure to select at least one contact before pressing.", 0);
    return;
  end
  ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), str);
end

function gKH.ContactNotes:ShowAllContactNotes(cguid)
  ;
  local str, c = "<P>Contact notes table does not exist.</P>", 0;
  if self.Data ~= nil then
    str = "";
    for _, v in pairs(self.Data) do
      str = str .. string.format("<P>ContactName: %s , Side: %s , Notes: %s </P>", v.lastname, v.side, v.note);
      c = c + 1;
    end
    if c == 0 then str = "<P>No contact notes exist.</P>"; end
  end
  ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), str);
end

--Basically validate that all note records have a valid matching contactguid still.
--If they don't remove them, and then set the next schedule time to run.
--Also update lastname as it could have changed over time.
function gKH.ContactNotes:ScavengeRecords(curtime, log, gui)
  ;
  if log == nil then log = false; end
  if gui == nil then gui = false; end
  if curtime == nil then curtime = ScenEdit_CurrentTime(); end
  if self.ScavengerNextRuntime == nil then self.ScavengerNextRuntime = 0; end
  if gui then self.ScavengerNextRuntime = 0; end
  if ((self.ScavengerNextRuntime == 0)) or (curtime >= self.ScavengerNextRuntime) then
    local retval, ct, updcount, scavcount = false, nil, 0, 0;
    local rmtable = {};
    for k, v in pairs(self.Data) do
      local isvalid = false;
      retval, ct = pcall(ScenEdit_GetContact, { side = self.ScavengerSide, guid = k }); --try to get side view
      if ((retval == true) and ct ~= nil) and ct.guid ~= nil then
        isvalid = true;
      elseif ((retval == false) or ct == nil) or ct.guid == nil then
        retval, ct = pcall(VP_GetContact, { guid = k }); --try to get overall contact view; handle special 'group' contacts.
        if ((retval == true) and ct ~= nil) and ct.guid ~= nil then
          isvalid = true;
        end
      else
        isvalid = false;
      end

      if isvalid then                                     -- we have a valid record.
        v.lastname = ct.name;
        if ct.side ~= nil then v.side = ct.side.name; end --will cheat for special objects sadly.
        updcount = updcount + 1
      else
        rmtable[k] = true; --flag it so we're not changing the array while transvering it.
      end
    end
    for k, _ in pairs(rmtable) do
      self.Data[k] = nil;
      scavcount = updcount + 1
    end
    gKH.State.SaveTableToKey(self.Data, self.SaveKeyName);
    self.ScavengerNextRuntime = curtime + self.ScavengerCycletime;
    if log then print('Scavanging completed. scavcount: ' .. tostring(scavcount) .. " updcount: " .. tostring(updcount)); end
    if gui then
      ScenEdit_MsgBox(
        'Scavanging completed. scavcount: ' .. tostring(scavcount) .. " updcount: " .. tostring(updcount), 0);
    end
  else
    if log then print('Not scavange time yet'); end
  end
end

--Startup routine.
function gKH.ContactNotes:bootstrap()
  ;
  local tmp = gKH.State.LoadTableFromKey(self.SaveKeyName);  -- get existing data if it exists.
  if tmp ~= nil then
    self.Data = tmp;                                         -- it existed assign it.
  end
  self:ScavengeRecords(ScenEdit_CurrentTime(), true, false); --force revalidate data and set SavangerNextRuntime as it will be 0 after load.
end

-- end functions --

-- invoke bootstrapper to restore data and re-validate data --
gKH.ContactNotes:bootstrap();
print('ContactNotes library successfully loaded.');
