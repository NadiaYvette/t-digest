--  tree234.ads
--
--  Generic array-backed 2-3-4 tree with monoidal measures.
--
--  Generic parameters:
--    Key_Type     - element type stored in sorted order
--    Measure_Type - monoidal annotation on subtrees
--    Measure_One  - compute measure for a single key
--    Combine      - monoidal combine of two measures
--    Identity     - monoidal identity element
--    Compare      - returns -1, 0, or +1

generic
   type Key_Type is private;
   type Measure_Type is private;
   with function Measure_One (K : Key_Type) return Measure_Type;
   with function Combine (A, B : Measure_Type) return Measure_Type;
   with function Identity return Measure_Type;
   with function Compare (A, B : Key_Type) return Integer;
   with function Weight_Of (M : Measure_Type) return Long_Float;
package Tree234 is

   --  Result of Find_By_Weight
   type Weight_Result is record
      Key        : Key_Type;
      Cum_Before : Long_Float := 0.0;
      Index      : Natural := 0;
      Found      : Boolean := False;
   end record;

   --  Dynamic key array for Collect / Build_From_Sorted
   type Key_Array is array (Positive range <>) of Key_Type;
   type Key_Array_Access is access Key_Array;

   --  The tree object
   type Tree is private;

   --  Insert a key into the tree (maintains sorted order).
   procedure Insert (T : in out Tree; K : Key_Type);

   --  Remove all elements.
   procedure Clear (T : in out Tree);

   --  Number of keys in the tree.
   function Size (T : Tree) return Natural;

   --  Root measure (monoidal summary of entire tree).
   function Root_Measure (T : Tree) return Measure_Type;

   --  Collect all keys in-order into Arr (1 .. Count).
   --  Arr must be large enough.
   procedure Collect (T     : Tree;
                      Arr   : out Key_Array;
                      Count : out Natural);

   --  Find a key by cumulative weight.
   function Find_By_Weight (T      : Tree;
                            Target : Long_Float) return Weight_Result;

   --  Build a balanced tree from a pre-sorted array.
   procedure Build_From_Sorted (T   : in out Tree;
                                Arr : Key_Array);

private

   No_Child : constant Integer := -1;

   type Child_Array is array (0 .. 3) of Integer;
   type Node_Key_Array is array (1 .. 3) of Key_Type;

   type Node is record
      N        : Natural := 0;            -- number of keys (1..3)
      Keys     : Node_Key_Array;
      Children : Child_Array := (others => No_Child);
      Measure  : Measure_Type;
   end record;

   --  Node pool: we use a simple expandable array + free list.
   Initial_Pool_Size : constant := 64;

   type Node_Array is array (Natural range <>) of Node;
   type Node_Array_Access is access Node_Array;

   type Int_Array is array (Natural range <>) of Integer;
   type Int_Array_Access is access Int_Array;

   type Tree is record
      Pool       : Node_Array_Access := null;
      Pool_Count : Natural := 0;        -- next slot to allocate
      Free_List  : Int_Array_Access := null;
      Free_Count : Natural := 0;
      Root       : Integer := No_Child;
      Count      : Natural := 0;        -- total number of keys
   end record;

end Tree234;
