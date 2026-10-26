import { assertEquals } from "jsr:@std/assert";
import { type BriefPackage, packageSentences } from "./packages.ts";

const now = new Date("2026-10-26T10:00:00Z");

const pkg = (over: Partial<BriefPackage>): BriefPackage => ({
  merchant: null,
  item: null,
  status: "shipped",
  expected_date: null,
  delivered_at: null,
  ...over,
});

const out = (merchant: string | null): BriefPackage =>
  pkg({ merchant, status: "out_for_delivery" });

function run(packages: BriefPackage[], tz = 0, at = now) {
  return packageSentences({ packages, now: at, tzOffsetMinutes: tz });
}

Deno.test("one labelled package in each group", () => {
  assertEquals(run([out("MediaMarkt")]), [
    "Your MediaMarkt package is out for delivery.",
  ]);
  assertEquals(
    run([pkg({ merchant: "Amazon", expected_date: "2026-10-26" })]),
    ["Your Amazon package is expected today."],
  );
  assertEquals(
    run([
      pkg({
        merchant: "Zalando",
        status: "delivered",
        delivered_at: "2026-10-26T08:00:00Z",
      }),
    ]),
    ["Your Zalando package was delivered today."],
  );
});

Deno.test("one unlabelled package", () => {
  assertEquals(run([out(null)]), ["A package is out for delivery."]);
  assertEquals(
    run([pkg({ merchant: "  ", expected_date: "2026-10-26" })]),
    ["A package is expected today."],
  );
  assertEquals(
    run([pkg({ status: "delivered", delivered_at: "2026-10-26T08:00:00Z" })]),
    ["A package was delivered today."],
  );
});

Deno.test("two packages", () => {
  assertEquals(run([out("MediaMarkt"), out("Amazon")]), [
    "2 packages are out for delivery: MediaMarkt and Amazon.",
  ]);
  assertEquals(
    run([
      pkg({ merchant: "X", status: "delivered", delivered_at: "2026-10-26T01:00:00Z" }),
      pkg({ merchant: "Y", status: "delivered", delivered_at: "2026-10-26T02:00:00Z" }),
    ]),
    ["2 packages were delivered today: X and Y."],
  );
});

Deno.test("three packages are all named", () => {
  const day = "2026-10-26";
  assertEquals(
    run(["A", "B", "C"].map((m) => pkg({ merchant: m, expected_date: day }))),
    ["3 packages are expected today: A, B and C."],
  );
});

Deno.test("five packages name three and count the rest", () => {
  assertEquals(run(["A", "B", "C", "D", "E"].map(out)), [
    "5 packages are out for delivery: A, B, C and 2 more.",
  ]);
});

Deno.test("unlabelled packages count as more", () => {
  assertEquals(run([out("A"), out(null), out(null)]), [
    "3 packages are out for delivery: A and 2 more.",
  ]);
  assertEquals(run([out(null), out(null)]), [
    "2 packages are out for delivery.",
  ]);
});

Deno.test("item is the fallback label", () => {
  assertEquals(
    run([pkg({ item: "Headphones", status: "out_for_delivery" })]),
    ["Your Headphones package is out for delivery."],
  );
});

Deno.test("expected tomorrow gives nothing", () => {
  assertEquals(
    run([pkg({ merchant: "Amazon", expected_date: "2026-10-27" })]),
    [],
  );
});

Deno.test("delivered package with an expected date today only counts as delivered", () => {
  assertEquals(
    run([
      pkg({
        merchant: "Amazon",
        status: "delivered",
        expected_date: "2026-10-26",
        delivered_at: "2026-10-26T08:00:00Z",
      }),
    ]),
    ["Your Amazon package was delivered today."],
  );
});

Deno.test("delivered yesterday gives nothing", () => {
  assertEquals(
    run([
      pkg({
        merchant: "Amazon",
        status: "delivered",
        delivered_at: "2026-10-25T08:00:00Z",
      }),
    ]),
    [],
  );
});

Deno.test("local date can differ from the UTC date", () => {
  const late = new Date("2026-10-26T23:30:00Z");
  assertEquals(
    run([pkg({ merchant: "Amazon", expected_date: "2026-10-27" })], 120, late),
    ["Your Amazon package is expected today."],
  );
  assertEquals(
    run([pkg({ merchant: "Amazon", expected_date: "2026-10-26" })], 120, late),
    [],
  );
  // 22:30Z is 00:30 local on the 27th, so it counts as delivered today.
  assertEquals(
    run(
      [
        pkg({
          merchant: "Zalando",
          status: "delivered",
          delivered_at: "2026-10-26T22:30:00Z",
        }),
      ],
      120,
      late,
    ),
    ["Your Zalando package was delivered today."],
  );
});

Deno.test("all three groups come in order", () => {
  assertEquals(
    run([
      pkg({ merchant: "Zalando", status: "delivered", delivered_at: "2026-10-26T06:00:00Z" }),
      pkg({ merchant: "Amazon", expected_date: "2026-10-26" }),
      out("MediaMarkt"),
    ]),
    [
      "Your MediaMarkt package is out for delivery.",
      "Your Amazon package is expected today.",
      "Your Zalando package was delivered today.",
    ],
  );
});
