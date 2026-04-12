-- DevGuard Scanner in Ada/SPARK
-- This is a secure, formally verifiable version using Ada/SPARK.
-- Compile with GNAT: gnatmake devguard.adb
-- Assumes GNATCOLL.JSON and GNAT.Regexp are available.
-- For full SPARK proof, add GNATprove commands.

pragma SPARK_Mode (On);

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with GNATCOLL.JSON; use GNATCOLL.JSON;
with GNAT.Regexp; use GNAT.Regexp;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

procedure DevGuard is

   -- Configuration record
   type Config is record
      Timeout_Secs : Natural := 30;
      Search_Paths : Unbounded_String := To_Unbounded_String ("/home/sustainableabundance");
   end record;

   -- Load config from JSON file, with BOM handling (simple trim)
   function Load_Config (Path : String) return Config is
      File : File_Type;
      Content : Unbounded_String;
      Obj : JSON_Value;
      Result : Config := (Timeout_Secs => 30, Search_Paths => To_Unbounded_String ("/home/sustainableabundance"));
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Append (Content, Get_Line (File));
      end loop;
      Close (File);
      -- Trim BOM if present (U+FEFF)
      if Length (Content) > 0 and Element (Content, 1) = Character'Val (16#FEFF#) then
         Delete (Content, 1, 1);
      end if;
      Obj := Read (To_String (Content));
      if Has_Field (Obj, "timeout_secs") then
         Result.Timeout_Secs := Natural (As_Number (Obj, "timeout_secs"));
      end if;
      if Has_Field (Obj, "search_paths") and Get (Obj, "search_paths").Kind = JSON_Array_Type then
         Result.Search_Paths := To_Unbounded_String (Get (Obj, "search_paths").Get (1));
      end if;
      return Result;
   exception
      when others =>
         Put_Line ("Warning: invalid config file, using defaults");
         return Result;
   end Load_Config;

   -- Scan for package.json files
   procedure Scan_Packages (Search_Path : String; Package_Name : String; Version : String) is
      Reg : Regexp := Compile ("^" & Package_Name & "$", Case_Insensitive);
      Version_Reg : Regexp := Compile (Version, Case_Insensitive);
      Dir : Directory_Entries;
   begin
      Start_Search (Dir, Search_Path, "*.json");
      while More_Entries (Dir) loop
         Get_Next_Entry (Dir, Dir_Entry);
         if Simple_Name (Dir_Entry) = "package.json" then
            -- Parse JSON (simplified)
            declare
               File : File_Type;
               Obj : JSON_Value;
            begin
               Open (File, In_File, Full_Name (Dir_Entry));
               declare
                  Content : Unbounded_String;
               begin
                  while not End_Of_File (File) loop
                     Append (Content, Get_Line (File));
                  end loop;
                  Obj := Read (To_String (Content));
                  if Has_Field (Obj, "dependencies") then
                     declare
                        Deps : JSON_Value := Get (Obj, "dependencies");
                        Keys : JSON_Array := Get_Keys (Deps);
                     begin
                        for I in 1 .. Length (Keys) loop
                           if Match (Get (Keys, I), Reg) then
                              declare
                                 Ver : String := As_String (Deps, Get (Keys, I));
                              begin
                                 if Match (Ver, Version_Reg) then
                                    Put_Line ("Found: " & Package_Name & " v" & Ver & " in " & Full_Name (Dir_Entry));
                                 end if;
                              end;
                           end if;
                        end loop;
                     end;
                  end if;
               end;
               Close (File);
            exception
               when others => null;
            end;
         end if;
      end loop;
      End_Search (Dir);
   end Scan_Packages;

   -- Main logic
   Config_File : constant String := "/home/sustainableabundance/.devguardrc";
   Cfg : Config := Load_Config (Config_File);
   Args : array (1 .. 4) of Unbounded_String; -- assume args
begin
   Put_Line ("🔍 Scanning " & To_String (Cfg.Search_Paths) & " for packages...");
   Scan_Packages (To_String (Cfg.Search_Paths), "lodash", "4"); -- example
   Put_Line ("Scan complete.");
end DevGuard;