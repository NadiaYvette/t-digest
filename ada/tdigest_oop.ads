--  tdigest_oop.ads
--
--  Object-oriented (tagged-type) interface for the Dunning t-digest.
--  Wraps the record-based TDigest package with Ada tagged types and
--  primitive operations.

with TDigest;

package TDigest_OOP is

   --  ---------------------------------------------------------------
   --  Tagged type
   --  ---------------------------------------------------------------

   type Digest_Type is tagged limited private;

   --  ---------------------------------------------------------------
   --  Construction
   --  ---------------------------------------------------------------

   --  Create a new digest with the given compression parameter.
   procedure Initialize (Self        : out Digest_Type;
                         Compression : Long_Float := 100.0);

   --  ---------------------------------------------------------------
   --  Primitive operations
   --  ---------------------------------------------------------------

   --  Add a value with an optional weight (default 1.0).
   procedure Add (Self   : in out Digest_Type;
                  Value  : Long_Float;
                  Weight : Long_Float := 1.0);

   --  Force compression of buffered values.
   procedure Compress (Self : in out Digest_Type);

   --  Estimate the value at quantile Q (0.0 .. 1.0).
   function Query_Quantile (Self : in out Digest_Type;
                            Q    : Long_Float) return Long_Float;

   --  Estimate the CDF at value X.
   function Query_CDF (Self : in out Digest_Type;
                       X    : Long_Float) return Long_Float;

   --  Merge another digest into this one.
   procedure Merge (Self  : in out Digest_Type;
                    Other : in out Digest_Type);

   --  Return the number of centroids (flushes buffer first).
   function Centroid_Count (Self : in out Digest_Type) return Natural;

   --  Return the total weight of all added values.
   function Total_Weight (Self : Digest_Type) return Long_Float;

   --  Return the observed minimum value.
   function Min_Value (Self : Digest_Type) return Long_Float;

   --  Return the observed maximum value.
   function Max_Value (Self : Digest_Type) return Long_Float;

private

   type Digest_Type is tagged limited record
      Impl : TDigest.T_Digest := TDigest.Create;
   end record;

end TDigest_OOP;
