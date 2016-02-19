------------------------------------------------------------------------------
--                        Bareboard drivers examples                        --
--                                                                          --
--                     Copyright (C) 2015-2016, AdaCore                     --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

with Bitmapped_Drawing; use Bitmapped_Drawing;

package body Tracks_Display is

   Entry_Sign_Size : constant := 6;

   Entry_Sign_Pixel : constant array (Entry_Sign_Color) of Graphics_Color
     := (Green => Bitmapped_Drawing.Green,
         Orange => Bitmapped_Drawing.Orange,
         Red => Bitmapped_Drawing.Red);

   Track_Color      : constant Graphics_Color := Bitmapped_Drawing.Light_Gray;
   Track_Thickness  : constant := 4;
   Train_Thickness  : constant := 2;
   Switch_Color     : constant Graphics_Color := Bitmapped_Drawing.Violet;
   Switch_Thickness : constant := 2;

   use type Trains.Train_Id;

   function First_Bogie_Track (Train : Displayed_Train) return Trains.Track_Id;

   function Last_Bogie_Track (Train : Displayed_Train) return Trains.Track_Id;

   function As_Display_Point (Input : Screen_Interface.Point)
     return Bitmapped_Drawing.Point;

   --------------------------
   -- Build_Straight_Track --
   --------------------------

   procedure Build_Straight_Track
     (Track : in out Displayed_Track;
      Start, Stop : Screen_Interface.Point)
   is
      Diff_X : constant Float := (Float(Stop.X) - Float(Start.X))
        / (Float (Track.Points'Length) - 1.0);

      Diff_Y : constant Float := (Float(Stop.Y) - Float(Start.Y))
        / (Float (Track.Points'Length) - 1.0);

   begin
      for I in Track.Points'Range loop
         declare
            T : constant Float := (Float (I) - 1.0);
         begin
            Track.Points (I).X := Natural (Float (Start.X) + T * Diff_X);
            Track.Points (I).Y := Natural (Float (Start.Y) + T * Diff_Y);
         end;
      end loop;
      Track.Is_Straight := True;

      --  Default Sign Position
      Set_Sign_Position (Track, Top);
   end Build_Straight_Track;

   -----------------------
   -- Build_Curve_Track --
   -----------------------

   procedure Build_Curve_Track
     (Track          : in out Displayed_Track;
      P1, P2, P3, P4 : Screen_Interface.Point)
   is
   begin
      for I in Track.Points'Range loop
         declare
            T : constant Float := Float (I) / Float (Track.Points'Length);
            A : constant Float := (1.0 - T)**3;
            B : constant Float := 3.0 * T * (1.0 - T)**2;
            C : constant Float := 3.0 * T**2 * (1.0 - T);
            D : constant Float := T**3;
         begin
            Track.Points (I).X := Natural (A * Float (P1.X) +
                                             B * Float (P2.X) +
                                             C * Float (P3.X) +
                                             D * Float (P4.X));
            Track.Points (I).Y := Natural (A * Float (P1.Y) +
                                             B * Float (P2.Y) +
                                             C * Float (P3.Y) +
                                             D * Float (P4.Y));
         end;
      end loop;
      Track.Is_Straight := False;

      --  Fix first and last coordinate
      Track.Points (Track.Points'First) := P1;
      Track.Points (Track.Points'Last) := P4;

      --  Default Sign Position
      Set_Sign_Position (Track, Top);
   end Build_Curve_Track;

   -----------------------
   -- Set_Sign_Position --
   -----------------------

   procedure Set_Sign_Position
     (Track : in out Displayed_Track;
      Pos   : Entry_Sign_Position)
   is
      First : constant Screen_Interface.Point :=
                Track.Points (Track.Points'First);
      Coord  : Screen_Interface.Point;
   begin
      case Pos is
         when Top =>
            Coord := (First.X - Natural (Entry_Sign_Size * 1.5), First.Y);
         when Left =>
            Coord := (First.X, First.Y + Natural (Entry_Sign_Size * 1.5));
         when Bottom =>
            Coord := (First.X + Natural (Entry_Sign_Size * 1.5), First.Y);
         when Right =>
            Coord := (First.X, First.Y - Natural (Entry_Sign_Size * 1.5));
      end case;

      Track.Entry_Sign.Coord := Coord;
   end Set_Sign_Position;

   -------------------
   -- Connect_Track --
   -------------------

   procedure Connect_Track
     (Track  : in out Displayed_Track;
      E1, E2 : Track_Access)
   is
   begin
      if E1 = null then
         raise Program_Error;
      else
         Track.Exits (S1) := E1;
         Track.Switch_State := S1;
         Track.Switchable := False;

         --  Connected track should share point coordinate
         if Track.Points (Track.Points'Last) /=
           E1.all.Points (E1.all.Points'First) then
            raise Program_Error;
         end if;

      end if;

      if E2 /= null then
         Track.Exits (S2) := E2;
         Track.Switchable := True;
         E2.Entry_Sign.Disabled := True;

         --  Connected track should share point coordinate
         if Track.Points (Track.Points'Last) /=
           E2.all.Points (E2.all.Points'First) then
            raise Program_Error;
         end if;

      end if;
   end Connect_Track;

   ----------------
   -- Init_Train --
   ----------------

   procedure Init_Train
     (Train : in out Displayed_Train;
      Track : Track_Access)
   is
      Cnt : Natural := 1;
   begin
      if Train.Bogie_Capacity > Track.all.Points'Length then
         --  Not enough space to put the train.
         raise Program_Error;
      end if;

      Train.Id := Trains.Cur_Num_Trains;

      for Bog of Train.Bogies loop
         Bog.Track := Track;
         Bog.Track_Pos := Track.all.Points'First + Train.Bogie_Capacity - Cnt;

         if Bog.Track_Pos not in Track.Points'Range then
            raise Program_Error;
         end if;
         Cnt := Cnt + 1;
      end loop;
   end Init_Train;

   ----------------
   -- Next_Track --
   ----------------

   function Next_Track (Track : Track_Access) return Track_Access is
   begin
      if Track.all.Switchable
        and then Track.all.Switch_State = S2
      then
         return Track.all.Exits (S2);
      else
         return Track.all.Exits (S1);
      end if;
   end Next_Track;

   ----------------
   -- Move_Bogie --
   ----------------

   procedure Move_Bogie (Bog : in out Bogie) is
   begin
      if Bog.Track_Pos = Bog.Track.all.Points'Last then
         Bog.Track := Next_Track (Bog.Track);

         --  The first point of track has the same position has the last of
         --  previous tack, so we skip it.
         Bog.Track_Pos := Bog.Track.all.Points'First + 1;
      else
         Bog.Track_Pos := Bog.Track_Pos + 1;
      end if;
   end Move_Bogie;

   ----------------
   -- Move_Train --
   ----------------

   procedure Move_Train (Train : in out Displayed_Train) is
      use type Trains.Move_Result;
      Cnt : Integer := 0;
      Train_Copy : Displayed_Train (Train.Bogie_Capacity);
      Sign_Command : Trains.Move_Result;
   begin
      loop
         --  Make a copy of the train and move it
         Train_Copy := Train;

         --  Each bogie takes the previous position of the bogie in front him
         for Index in reverse Train_Copy.Bogies'First + 1 .. Train_Copy.Bogies'Last loop
            Train_Copy.Bogies (Index) := Train_Copy.Bogies (Index - 1);
         end loop;

         --  To move the first bogie we need to see if we are at the end of a
         --  track and maybe a switch.
         Move_Bogie (Train_Copy.Bogies (Train_Copy.Bogies'First));

         --  Check if that move was legal
         Trains.Move (Train_Copy.Id,
                      (First_Bogie_Track (Train_Copy),
                       0,
                       Last_Bogie_Track (Train_Copy)),
                      Sign_Command);

         if Sign_Command /= Trains.Stop then
            --  Redraw the track under the last bogie. This is an optimisation
            --  to avoid redrawing all tracks at each loop.
            Draw_Line
              (Screen_Buffer,
               As_Display_Point (Location (Train.Bogies (Train.Bogies'Last))),
               As_Display_Point (Location (Train.Bogies (Train.Bogies'Last - 1))),
               Track_Color,
               Track_Thickness);

            --  This move is ilegal, set train to the new position
            Train := Train_Copy;
         end if;

         case Sign_Command is
            when Trains.Full_Speed =>
               Train.Speed := 3;
            when Trains.Slow_Down =>
               Train.Speed := 1;
            when Trains.Stop =>
               Train.Speed := 0;
            when Trains.Keep_Going =>
               --  Keep the same speed
               null;
         end case;

         exit when Train.Speed <= Cnt;

         Cnt := Cnt + 1;
      end loop;
   end Move_Train;

   ---------------
   -- Draw_Sign --
   ---------------

   procedure Draw_Sign (Track : Displayed_Track) is
   begin
      if (Track.Entry_Sign.Coord /= (0, 0)) then
         if not Track.Entry_Sign.Disabled then
            Fill_Circle
              (Screen_Buffer,
               As_Display_Point (Track.Entry_Sign.Coord),
               Entry_Sign_Size / 2,
               Entry_Sign_Pixel (Track.Entry_Sign.Color));
         else
            --  Draw a black circle to "erase" the previous drawing
            Fill_Circle
              (Screen_Buffer,
               As_Display_Point (Track.Entry_Sign.Coord),
               Entry_Sign_Size / 2,
               Bitmapped_Drawing.Black);
         end if;
      end if;
   end Draw_Sign;

   ----------------
   -- Draw_Track --
   ----------------

   procedure Draw_Track (Track : Displayed_Track) is
   begin
      if Track.Is_Straight then
         Draw_Line
           (Screen_Buffer,
            As_Display_Point (Track.Points (Track.Points'First)),
            As_Display_Point (Track.Points (Track.Points'Last)),
            Track_Color,
            Track_Thickness);
      else
         for Index in Track.Points'First .. Track.Points'Last - 1 loop
            Draw_Line
              (Screen_Buffer,
               As_Display_Point (Track.Points (Index)),
               As_Display_Point (Track.Points (Index + 1)),
               Track_Color,
               Track_Thickness);
         end loop;
      end if;

      Draw_Sign (Track);
   end Draw_Track;

   -----------------
   -- Draw_Switch --
   -----------------

   procedure Draw_Switch (Track : Displayed_Track) is
      Target : constant Track_Access := Track.Exits (Track.Switch_State);
   begin
      if Track.Switchable then
         For Cnt in Target.Points'First .. Target.Points'First + 10 loop
            declare
               P1 : constant Screen_Interface.Point :=
                      Target.all.Points (Cnt);
               P2 : constant Screen_Interface.Point :=
                      Target.all.Points (Cnt + 1);
            begin
               Draw_Line
                 (Screen_Buffer,
                  As_Display_Point (P1),
                  As_Display_Point (P2),
                  Switch_Color,
                  Switch_Thickness);
            end;
         end loop;
      end if;
   end Draw_Switch;

   ----------------
   -- Draw_Train --
   ----------------

   procedure Draw_Train (Train : Displayed_Train) is
      Train_Color : Graphics_Color;
   begin
      for Index in Train.Bogies'First .. Train.Bogies'Last - 1 loop
         declare
            B1     : constant Bogie := Train.Bogies (Index);
            Track1 : constant Track_Access := B1.Track;
            P1     : constant Screen_Interface.Point :=
                       Track1.Points (B1.Track_Pos);
            B2     : constant Bogie := Train.Bogies (Index + 1);
            Track2 : constant Track_Access := B2.Track;
            P2     : constant Screen_Interface.Point :=
                       Track2.Points (B2.Track_Pos);
         begin
            case Train.Speed is
               when 0 =>
                  Train_Color := Bitmapped_Drawing.Red;
               when 1 =>
                  Train_Color := Bitmapped_Drawing.Orange;
               when others =>
                  Train_Color := Bitmapped_Drawing.Black;
            end case;
            Draw_Line
              (Screen_Buffer,
               As_Display_Point (P1),
               As_Display_Point (P2),
               Train_Color,
               Train_Thickness);
         end;
      end loop;
   end Draw_Train;

   -----------------
   -- Update_Sign --
   -----------------

   procedure Update_Sign (Track : in out Displayed_Track) is
      Prev_Color : constant Entry_Sign_Color := Track.Entry_Sign.Color;
   begin
      case Trains.Track_Signals (Track.Id) is
         when Trains.Green =>
            Track.Entry_Sign.Color := Green;
         when Trains.Orange =>
            Track.Entry_Sign.Color := Orange;
            Draw_Track (Track);
         when Trains.Red =>
            Track.Entry_Sign.Color := Red;
      end case;
      if Track.Entry_Sign.Color /= Prev_Color then
         Draw_Sign (Track);
      end if;
   end Update_Sign;

   -------------------
   -- Change_Switch --
   -------------------

   procedure Change_Switch (Track : in out Displayed_Track) is
   begin
      if Track.Switch_State = S1 then
         Track.Switch_State := S2;
         Track.Exits (S1).Entry_Sign.Disabled := True;
         Track.Exits (S2).Entry_Sign.Disabled := False;
      else
         Track.Switch_State := S1;
         Track.Exits (S2).Entry_Sign.Disabled := True;
         Track.Exits (S1).Entry_Sign.Disabled := False;
      end if;

      Draw_Track (Track.Exits (S1).all);
      Draw_Track (Track.Exits (S2).all);
      Draw_Track (Track);
   end Change_Switch;

   --------------
   -- Location --
   --------------

   function Location (This : Bogie) return Screen_Interface.Point is
   begin
      return This.Track.Points (This.Track_Pos);
   end Location;

   -----------------------
   -- First_Bogie_Track --
   -----------------------

   function First_Bogie_Track (Train : Displayed_Train) return Trains.Track_Id is
      First_Bogie : constant Bogie := Train.Bogies (Train.Bogies'First);
   begin
      return First_Bogie.Track.Id;
   end First_Bogie_Track;

   ----------------------
   -- Last_Bogie_Track --
   ----------------------

   function Last_Bogie_Track (Train : Displayed_Train) return Trains.Track_Id is
      Last_Bogie : constant Bogie := Train.Bogies (Train.Bogies'Last);
   begin
      return Last_Bogie.Track.Id;
   end Last_Bogie_Track;

   -----------------
   -- Start_Coord --
   -----------------

   function Start_Coord (Track : Displayed_Track) return Screen_Interface.Point
   is
   begin
      return Track.Points (1);
   end Start_Coord;

   ---------------
   -- End_Coord --
   ---------------

   function End_Coord (Track : Displayed_Track) return Screen_Interface.Point
   is
   begin
      return Track.Points (Track.Points'Last);
   end End_Coord;

   ----------------------
   -- As_Display_Point --
   ----------------------

   function As_Display_Point
     (Input : Screen_Interface.Point)
      return Bitmapped_Drawing.Point
   is
     (Input.X, Input.Y);

end Tracks_Display;
