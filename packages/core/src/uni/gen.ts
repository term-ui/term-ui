#!/usr/bin/env bun

import {
  readFileSync,
  writeFileSync,
} from "node:fs";
import path, { resolve } from "node:path";
import {
  argv,
  exit,
  stderr,
  stdin,
  stdout,
} from "node:process";
import {
  camelCase,
  findIndex,
  isEqual,
  snakeCase,
  uniqBy,
  upperFirst,
} from "lodash-es";
import dedent from "ts-dedent";
const upperCamelCase = (str: string) =>
  upperFirst(camelCase(str));
import { existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
const __dirname = dirname(
  fileURLToPath(import.meta.url),
);

const files: {
  path: string;
  url: string;
  type: "bool" | "enum";
  defaultValue: boolean | string;
  name: string;
}[] = [
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/auxiliary/GraphemeBreakProperty.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/auxiliary/GraphemeBreakProperty.txt",
    type: "enum",
    defaultValue: "Other",
    name: "GraphemeBreak",
  },
  // {
  //   path: "data/16.0.0/ucd/auxiliary/WordBreakProperty.txt",
  //   url: "https://www.unicode.org/Public/16.0.0/ucd/auxiliary/WordBreakProperty.txt",
  // },
  // {
  //   path: "data/16.0.0/ucd/auxiliary/SentenceBreakProperty.txt",
  //   url: "https://www.unicode.org/Public/16.0.0/ucd/auxiliary/SentenceBreakProperty.txt",
  // },
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/extracted/DerivedLineBreak.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/extracted/DerivedLineBreak.txt",
    type: "enum",
    defaultValue: "XX",
    name: "LineBreak",
  },
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/emoji/emoji-data.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/emoji/emoji-data.txt",
    type: "bool",
    defaultValue: true,
    name: "Emoji",
  },
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/DerivedCoreProperties.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/DerivedCoreProperties.txt",
    type: "enum",
    defaultValue: "none",
    name: "CoreProperty",
  },
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/extracted/DerivedEastAsianWidth.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/extracted/DerivedEastAsianWidth.txt",
    type: "enum",
    defaultValue: "N",
    name: "EastAsianWidth",
  },
  {
    path: path.join(
      __dirname,
      "data/16.0.0/ucd/extracted/DerivedGeneralCategory.txt",
    ),
    url: "https://www.unicode.org/Public/16.0.0/ucd/extracted/DerivedGeneralCategory.txt",
    type: "enum",
    defaultValue: "X",
    name: "GeneralCategory",
  },
];

async function downloadFiles() {
  for (const file of files) {
    if (existsSync(file.path)) {
      console.log(
        `✔ Already exists, skipping: ${file.path}`,
      );
      continue;
    }

    const dir = dirname(file.path);
    mkdirSync(dir, { recursive: true });

    try {
      const response = await fetch(file.url);
      if (!response.ok) {
        console.error(
          `✖ Failed to download ${file.url}: ${response.statusText}`,
        );
        continue;
      }

      const content = await response.text();
      writeFileSync(file.path, content, "utf8");
      console.log(`⬇ Downloaded: ${file.path}`);
    } catch (error) {
      console.error(
        `✖ Error downloading ${file.url}:`,
        error,
      );
    }
  }

  console.log(
    "✨ Unicode data files check complete.",
  );
}
/**
 * Return smallest possible integer size for the given array.
 */
const max = (numbers: number[]): number => {
  let max = Number.MIN_SAFE_INTEGER;
  for (const number of numbers) {
    if (number > max) {
      max = number;
    }
  }
  return max;
};
function getsize(data: number[]): number {
  const maxdata = max(data);
  if (maxdata < 0x100) {
    return 1;
  }
  if (maxdata < 0x10000) {
    return 2;
  }
  return 4;
}

/**
 * Split a table to save space.
 * This function can be useful to save space if many of the ints are the same.
 * t1 and t2 are arrays of ints, and shift is an int, chosen to minimize the
 * combined size of t1 and t2 (in Zig code), and where for each i in range(len(t)),
 * t[i] == t2[(t1[i >> shift] << shift) + (i & mask)]
 * where mask is a bitmask isolating the last "shift" bits.
 */
function splitbins(
  t: number[],
): [number[], number[], number] {
  let n = t.length - 1; // last valid index
  let maxshift = 0; // the most we can shift n and still have something left
  if (n > 0) {
    while (n >> 1) {
      n >>= 1;
      maxshift += 1;
    }
  }

  let bytes = Number.MAX_SAFE_INTEGER; // smallest total size so far
  let best: [number[], number[], number] = [
    [],
    [],
    0,
  ];

  for (
    let shift = 0;
    shift <= maxshift;
    shift++
  ) {
    const t1: number[] = [];
    const t2: number[] = [];
    const size = 2 ** shift;
    const bincache: Map<string, number> =
      new Map();

    for (let i = 0; i < t.length; i += size) {
      // Create bin as a slice of the original array
      const bin = t.slice(i, i + size);

      const binKey = bin.join(",");

      let index = bincache.get(binKey);
      if (typeof index === "undefined") {
        index = t2.length;
        bincache.set(binKey, index);

        // Add all elements from bin to t2 without using spread
        for (let j = 0; j < bin.length; j++) {
          t2.push(bin[j]); // Add all elements, including any undefined values
        }
      }
      t1.push(index >> shift);
    }

    // determine memory size
    const b =
      t1.length * getsize(t1) +
      t2.length * getsize(t2);
    if (b < bytes) {
      best = [t1, t2, shift];
      bytes = b;
    }
  }

  return best;
}

/**
 * A class which represents a property argument.
 */
class PropArg {
  name: string;
  path: string;

  constructor(arg: string) {
    if (arg.includes("=")) {
      const parts = arg.split("=", 2);
      this.name = parts[0]?.trim() || "";
      this.path = parts[1]?.trim() || "";
    } else {
      this.name = "";
      this.path = arg.trim();
    }
  }

  /**
   * Read the file content
   */
  readStream(): string {
    if (this.path === "-") {
      // Read from stdin - for Bun, we'd need to read synchronously from stdin
      return readFileSync(0, "utf-8"); // file descriptor 0 is stdin
    }
    return readFileSync(this.path, "utf-8");
  }
}

/**
 * Parse UCD property files and extract code point properties
 */
function iterCodePointProperties(
  content: string,
): Array<[number, { fields: string[] }]> {
  const result: Array<
    [number, { fields: string[] }]
  > = [];
  const lines = content.split("\n");

  for (const line of lines) {
    // Skip comments and empty lines
    if (
      line.trim() === "" ||
      line.startsWith("#")
    ) {
      continue;
    }

    // Remove comments at the end of line
    const commentPos = line.indexOf("#");
    const actualLine =
      commentPos >= 0
        ? line.substring(0, commentPos)
        : line;

    // Parse the line
    const parts = actualLine
      .split(";")
      .map((part) => part.trim());

    // Handle code point ranges (e.g., 0000..007F)
    if (parts.length > 0) {
      const codePointPart = parts[0];
      if (codePointPart?.includes("..")) {
        const rangeParts =
          codePointPart.split("..");
        if (
          rangeParts.length === 2 &&
          rangeParts[0] &&
          rangeParts[1]
        ) {
          const start = Number.parseInt(
            rangeParts[0],
            16,
          );
          const end = Number.parseInt(
            rangeParts[1],
            16,
          );
          if (
            !Number.isNaN(start) &&
            !Number.isNaN(end)
          ) {
            for (
              let cp = start;
              cp <= end;
              cp++
            ) {
              result.push([
                cp,
                { fields: [parts.slice(1).join("_")] },
              ]);
            }
          }
        }
      } else if (codePointPart) {
        const cp = Number.parseInt(
          codePointPart,
          16,
        );
        if (!Number.isNaN(cp)) {
          result.push([cp, { fields: [parts.slice(1).join("_")] }]);
        }
      }
    }
  }

  return result;
}

/**
 * Group items by a key function
 */
function groupBy<
  T,
  K extends string | number | symbol,
>(
  items: T[],
  keyFn: (item: T) => K,
): Map<K, T[]> {
  const result = new Map<K, T[]>();

  for (const item of items) {
    const key = keyFn(item);
    if (!result.has(key)) {
      result.set(key, []);
    }
    const group = result.get(key);
    if (group) {
      group.push(item);
    }
  }

  return result;
}

/**
 * Sort string arrays lexicographically to match Python's tuple sorting
 */
function compareStringArrays(
  a: string[],
  b: string[],
): number {
  const minLength = Math.min(a.length, b.length);

  for (let i = 0; i < minLength; i++) {
    const aVal = a[i] || "";
    const bVal = b[i] || "";
    if (aVal < bVal) return -1;
    if (aVal > bVal) return 1;
  }

  return a.length - b.length;
}

/**
 * Main function
 */
async function main() {
  // Simple argument parsing
  // if (argv.length < 3) {
  //   console.error(
  //     "Usage: build-db-lookups.ts [-o output_file] file1 [file2 ...]",
  //   );
  //   exit(1);
  // }

  // let outputFile = "-";
  // const files: PropArg[] = [];

  // // Parse arguments
  // for (let i = 2; i < argv.length; i++) {
  //   const arg = argv[i];
  //   if (arg === "-o" || arg === "--output") {
  //     if (i + 1 < argv.length) {
  //       const nextArg = argv[i + 1];
  //       if (nextArg !== undefined) {
  //         outputFile = nextArg;
  //         i++;
  //       } else {
  //         console.error(
  //           "Error: Missing argument for -o/--output",
  //         );
  //         exit(1);
  //       }
  //     } else {
  //       console.error(
  //         "Error: Missing argument for -o/--output",
  //       );
  //       exit(1);
  //     }
  //   } else if (arg !== undefined) {
  //     files.push(new PropArg(arg));
  //   }
  // }

  // Define the expected column order to match Python output
  // const expectedColumnOrder = [
  // 	"Grapheme_Cluster_Break",
  // 	"Word_Break",
  // 	"Sentence_Break",
  // 	"Line_Break",
  // 	"Math",
  // 	"Alphabetic",
  // 	"Lowercase",
  // 	"Uppercase",
  // 	"Cased",
  // 	"Case_Ignorable",
  // 	"Changes_When_Lowercased",
  // 	"Changes_When_Uppercased",
  // 	"Changes_When_Titlecased",
  // 	"Changes_When_Casefolded",
  // 	"Changes_When_Casemapped",
  // 	"ID_Start",
  // 	"ID_Continue",
  // 	"XID_Start",
  // 	"XID_Continue",
  // 	"Default_Ignorable_Code_Point",
  // 	"Grapheme_Extend",
  // 	"Grapheme_Base",
  // 	"Grapheme_Link",
  // 	"InCB",
  // 	"Emoji",
  // 	"Emoji_Presentation",
  // 	"Emoji_Modifier",
  // 	"Emoji_Modifier_Base",
  // 	"Emoji_Component",
  // 	"Extended_Pictographic",
  // ];
  console.log(files);

  // Process properties
  const names: string[] = [];
  // For debugging purposes, use a smaller Unicode range temporarily
  const maxUnicode = 0x10ffff; // Maximum Unicode code point (full range)
  const db: Array<string[]> = [];
  for (let i = 0; i <= maxUnicode; i++) {
    db.push([]);
  }
  console.log(db.length);
  // return;

  // Debug: print input files
  // console.error("Processing input files:");
  // for (const propArg of files) {
  // 	console.error(`File: ${propArg.path}, Name: ${propArg.name}`);
  // }

  const columnMap: Record<
    string,
    | {
        type: "bool";
        list: boolean[];
        index: number;
      }
    | {
        type: "enum";
        list: string[];
        index: number;
      }
  > = {};

  for (const file of files) {
    const content = readFileSync(
      file.path,
      "utf-8",
    );
    const items =
      iterCodePointProperties(content);

    // Convert items to a dictionary for faster lookup
    const itemDict = new Map(items);
    if (file.type === "bool") {
      // name = name.slice(5, -1);
      const map = new Map<string, boolean[]>();
      // const groupedItems = groupBy(items, (item) => item[1].fields[0] ?? "");
      for (const [cp, record] of items) {
        // const value = record.fields[0];
        for (const field of record.fields) {
          if (!map.has(field)) {
            map.set(
              field,
              new Array(maxUnicode + 1).fill(
                false,
              ),
            );
          }
          const values = map.get(field);
          if (!values) {
            throw new Error(
              "values is undefined",
            );
          }
          values[cp] = true;
        }
      }

      for (const [
        field,
        values,
      ] of map.entries()) {
        names.push(field);
        columnMap[field] = {
          index: names.length - 1,
          type: "bool",
          list: values,
        };
      }

      // columnMap[name] = names.length - 1;

      // console.log(groupedItems.get("Emoji"));
      // for (const [groupName, group] of groupedItems.entries()) {
      //   names.push(groupName);
      //   columnMap[groupName] = names.length - 1;

      // }

      continue;
    }
    if (file.type === "enum") {
      names.push(file.name);
      if (!file.defaultValue) {
        throw new Error(
          `Invalid property name: ${file.name}`,
        );
      }

      columnMap[file.name] = {
        index: names.length - 1,
        type: "enum",
        list: new Array(maxUnicode + 1).fill(
          file.defaultValue,
        ),
      };
      for (let cp = 0; cp <= maxUnicode; cp++) {
        const record = itemDict.get(cp);
        const value =
          record?.fields[0] ?? file.defaultValue;

        columnMap[file.name].list[cp] = value;
      }
    }

    // } else {
    // 	// Unnamed property
    // 	const groupedItems = groupBy(
    // 		items,
    // 		(item) => (item[1].fields[0] ?? "") as string,
    // 	);

    // 	// Debug: print grouped property names
    // 	// console.error(`Grouped property names from ${propArg.path}:`);
    // 	// console.error(Array.from(groupedItems.keys()).join(", "));

    // 	for (const [groupName, group] of groupedItems.entries()) {
    // 		// stderr.write(`${groupName}\n`);
    // 		console.log(groupName);
    // 		names.push(groupName);
    // 		columnMap[groupName] = names.length - 1;

    // 		// Convert group to a dictionary for faster lookup
    // 		const itemDict = new Map(group);

    // 		for (let cp = 0; cp <= maxUnicode; cp++) {
    // 			const record = itemDict.get(cp);
    // 			let value = "null";

    // 			if (record) {
    // 				if (record.fields.length === 1) {
    // 					value = "Y";
    // 				} else if (record.fields.length >= 2) {
    // 					value = record.fields[1] || "";
    // 				} else {
    // 					throw new Error(`Invalid record: ${JSON.stringify(record)}`);
    // 				}
    // 			}

    // 			if (cp === 65536) {
    // 				console.log(db[cp].length, "unnamed", groupName, value);
    // 			}
    // 			const dbEntry = db[cp];
    // 			if (dbEntry) {
    // 				dbEntry.push(value);
    // 			}
    // 		}
    // 	}
    // }
  }

  const indexPool = new Map<string, number>();
  const indices2: number[] = new Array(
    maxUnicode + 1,
  ).fill(0);
  const table: (boolean | string)[][] = [];
  for (let cp = 0; cp <= maxUnicode; cp++) {
    const row: (boolean | string)[] = [];
    for (const [
      name,
      { type, list },
    ] of Object.entries(columnMap)) {
      row.push(list[cp] ?? "");
    }
    const key = row.join(",");

    let index = indexPool.get(key);

    if (index === undefined) {
      index = indexPool.size;
      indexPool.set(key, index);
      table.push(row);
    }
    indices2[cp] = index;
  }
  // console.log(indices2)
  const [index1, index2, shift] =
    splitbins(indices2);
  console.log(index1, index2, shift);
  const shiftZigCode = dedent`
	pub const shift: usize = ${shift};
	`;
  const index1ZigCode = dedent`
	pub const index1 = [_]u9{
		${index1.map((val) => `${val}`).join(", ")}
	};
	`;

  const index2ZigCode = dedent`
  pub const index2 = [_]u9{
    ${index2.map((val) => `${val}`).join(", ")}
  };
  `;

  const valuesZigCode = dedent`
  pub const values = [_]Columns{
    ${table.map((record) => `    .{ ${record.map((val) => (typeof val === "boolean" ? JSON.stringify(val) : `.${val}`)).join(", ")} },`).join("\n")}
  };
  `;
  // ${enumColumns}
  let types = "";
  for (const [
    name,
    { type, list },
  ] of Object.entries(columnMap)) {
    if (type === "enum") {
      const unique = [...new Set(list)];
      types += dedent`
      pub const ${upperCamelCase(name)} = enum {
        ${unique.map((val) => `${val}`).join(",\n")},
      };
      `;
      types += "\n";
    } else {
      types += `pub const ${upperCamelCase(name)}Index: usize = ${columnMap[name].index};\n`;
    }
  }

  const columnsTuple = dedent`
  pub const Columns = struct {${names.map((name) => (columnMap[name]?.type === "bool" ? "bool" : `${upperCamelCase(name)}`)).join(", ")}};
  `;
  const zigCode = dedent`
  ${types}
  ${columnsTuple}
  ${valuesZigCode}
  ${shiftZigCode}
  ${index1ZigCode}
  ${index2ZigCode}

  `;
  // if (outputFile === "-") {
  //   stdout.write(zigCode);
  // } else {
  // mkdirSync(path.join(__dirname, "src/linebreak/"), {
  //   recursive: true,
  // });
  writeFileSync(
    path.join(__dirname, "lookups.zig"),
    zigCode,
  );
  console.error(
    `Output written to ${path.join(__dirname, "lookups.zig")}`,
  );
  // }
  return;
  // // sparse_records = tuple(tuple(items) for items in db)
  // const sparseRecords: string[][] = [];
  // for (const items of db) {
  // 	const innerArray: string[] = [];
  // 	for (const item of items) {
  // 		innerArray.push(item);
  // 	}
  // 	sparseRecords.push(innerArray);
  // }
  // // unique_records = tuple(sorted(set(sparse_records)))
  // const uniqueRecordsSet = uniqBy(sparseRecords, (record) => record.join(","));
  // console.log("found", sparseRecords[65536].join(","));
  // const uniqueRecords = uniqueRecordsSet.sort(compareStringArrays);
  // for (let i = 0; i < uniqueRecords.length; i++) {
  // 	console.log(uniqueRecords[i].join(","));
  // }

  // const indices = [];
  // for (const record of sparseRecords) {
  // 	const index = findIndex(uniqueRecords, (uniqueRecord) =>
  // 		isEqual(record, uniqueRecord),
  // 	);
  // 	indices.push(index);
  // }
  // const [index1, index2, shift] = splitbins(indices);

  // let enumColumns = "";
  // for (let i = 0; i < names.length; i++) {
  // 	const fields = new Set<string>();
  // 	const enumName = upperCamelCase(names[i]);
  // 	for (const record of uniqueRecords) {
  // 		fields.add(record[i]);
  // 	}
  // 	console.log(enumName, fields);
  // 	const enumValues = Array.from(fields)
  // 		.map((field) => `  ${field},`)
  // 		.join("\n");
  // 	fields.delete("null");
  // 	enumColumns += dedent`
  //     pub const ${enumName} = enum(u8) {
  //     ${enumValues}
  //     };
  //   `;
  // 	enumColumns += "\n";
  // }
  // const columnsTuple = dedent`
  // pub const Columns = struct {${names.map((name) => `${upperCamelCase(name)}`).join(", ")}};
  // `;
  // // const columnsZigCode = dedent`
  // // ${columnsTuple}
  // // pub const columns = [_]Columns{
  // //   ${names.map((name) => `    "${name}",`).join("\n")}
  // // };
  // // `;
  // const valuesZigCode = dedent`
  // pub const values = [_]Columns{
  //   ${uniqueRecords.map((record) => `    .{ ${record.map((val) => (val === "null" ? "null" : `.${val}`)).join(", ")} },`).join("\n")}
  // };
  // `;
  // const shiftZigCode = dedent`
  // pub const shift: usize = ${shift};
  // `;
  // const index1ZigCode = dedent`
  // pub const index1 = [_]u8{
  // 	${index1.map((val) => `${val}`).join(", ")}
  // };
  // `;

  // const index2ZigCode = dedent`
  // pub const index2 = [_]u8{
  //   ${index2.map((val) => `${val}`).join(", ")}
  // };
  // `;

  // const zigCode = dedent`
  // ${enumColumns}
  // ${columnsTuple}
  // ${valuesZigCode}
  // ${shiftZigCode}
  // ${index1ZigCode}
  // ${index2ZigCode}

  // `;
  // if (outputFile === "-") {
  // 	stdout.write(zigCode);
  // } else {
  // 	writeFileSync(outputFile, zigCode);
  // 	console.error(`Output written to ${outputFile}`);
  // }
  // // console.log(columnsZigCode);
  // // console.log(valuesZigCode);
  // // console.log(shiftZigCode);
  // // console.log(index1ZigCode);

  // return;
  // console.error("Column names in original order:");
  // console.error(JSON.stringify(names));

  // // Reorder columns to match expected order and pad missing ones
  // const orderedNames: string[] = [];
  // const columnMapping: number[] = [];

  // for (const expectedCol of expectedColumnOrder) {
  // 	const index = names.indexOf(expectedCol);
  // 	if (index !== -1) {
  // 		orderedNames.push(expectedCol);
  // 		columnMapping.push(index);
  // 	} else {
  // 		// Column is not in our data - add empty column
  // 		orderedNames.push(expectedCol);
  // 		columnMapping.push(-1); // -1 indicates a missing column
  // 	}
  // }

  // Add any remaining columns not in expected order
  // for (const col of names) {
  // 	if (!expectedColumnOrder.includes(col)) {
  // 		orderedNames.push(col);
  // 		columnMapping.push(names.indexOf(col));
  // 	}
  // }

  // console.error("Reordered columns:");
  // console.error(JSON.stringify(orderedNames));
  // console.error("Column mapping:");
  // console.error(JSON.stringify(columnMapping));

  // // Reorder and pad sparse records
  // 	const orderedSparseRecords: string[][] = [];
  // 	console.log(orderedSparseRecords.length);

  // 	// for (const record of db) {
  // 	// 	if (record) {
  // 	// 		const orderedRecord: string[] = [];

  // 	// 		for (const colIndex of columnMapping) {
  // 	// 			if (colIndex === -1) {
  // 	// 				orderedRecord.push(""); // Missing column
  // 	// 			} else {
  // 	// 				orderedRecord.push(record[colIndex] || "");
  // 	// 			}
  // 	// 		}

  // 	// 		orderedSparseRecords.push(orderedRecord);
  // 	// 	}
  // 	// }

  // 	// Debug: Print a few sample sparse records
  // 	// console.error("Sample sparse records after reordering (first 3):");
  // 	// for (let i = 0; i < Math.min(3, orderedSparseRecords.length); i++) {
  // 	// 	console.error(
  // 	// 		`Code point ${i.toString(16)}: ${JSON.stringify(orderedSparseRecords[i])}`,
  // 	// 	);
  // 	// }

  // 	// Find unique records and create indices
  // 	// We'll create a more reliable approach that doesn't depend on string joining
  // 	const uniqueRecordsMap = new Map<string, number>();
  // 	const uniqueRecords: string[][] = [];

  // 	for (const record of orderedSparseRecords) {
  // 		// Create a JSON string representation for consistent hashing
  // 		const key = record.join(",");

  // 		if (!uniqueRecordsMap.has(key)) {
  // 			uniqueRecordsMap.set(key, uniqueRecords.length);
  // 			uniqueRecords.push(record);
  // 		}
  // 	}

  // 	// Sort the unique records to match Python's behavior
  // 	uniqueRecords.sort(compareStringArrays);

  // 	// Update the map after sorting
  // 	uniqueRecordsMap.clear();
  // 	for (let i = 0; i < uniqueRecords.length; i++) {
  // 		uniqueRecordsMap.set(uniqueRecords[i].join(","), i);
  // 	}

  // 	// Create indices array
  // 	const indices: number[] = [];
  // 	for (const record of orderedSparseRecords) {
  // 		const key = record.join(",");
  // 		const index = uniqueRecordsMap.get(key);
  // 		indices.push(index !== undefined ? index : 0);
  // 	}

  // 	console.log(
  // 		indices.length,
  // 		indices.reduce((a, b) => a + b, 0),
  // 	);
  // 	// Split bins to optimize storage
  // 	const [index1, index2, shift] = splitbins(indices);

  // 	// Create Uint8Array for binary data
  // 	const bytes1 = new Uint8Array(index1);
  // 	console.log(bytes1.slice(-100), bytes1.length);
  // 	const bytes2 = new Uint8Array(index2);

  // 	console.log(uniqueRecords.length);
  // 	// Generate Zig code
  // 	const zigCode = `
  // // DO NOT EDIT. This file is generated automatically.

  // pub const columns = [_][]const u8{
  // ${names.map((name) => `    "${name}",`).join("\n")}
  // };

  // pub const values = [_][${names.length}][]const u8{
  // ${uniqueRecords
  // 	.map(
  // 		(record) =>
  // 			`    [_][]const u8{ ${record.map((val) => `"${val}"`).join(", ")} },`,
  // 	)
  // 	.join("\n")}

  // };
  // pub const shift: usize = ${shift};
  // pub const index1 = [_]u8{
  // ${Array.from(bytes1)
  // 	.map(
  // 		(b, i) => `${i % 16 === 0 ? "    " : ""}${b},${i % 16 === 15 ? "\n" : " "}`,
  // 	)
  // 	.join("")}
  // };

  // `;
  // 	// pub const index2 = [_]u8{
  // 	//   ${Array.from(bytes2)
  // 	//     .map((b, i) => `${i % 16 === 0 ? "    " : ""}${b},${i % 16 === 15 ? "\n" : " "}`)
  // 	//     .join("")}
  // 	//   };
  // 	// Write output
  // 	if (outputFile === "-") {
  // 		stdout.write(zigCode);
  // 	} else {
  // 		writeFileSync(outputFile, zigCode);
  // 		console.error(`Output written to ${outputFile}`);
  // 	}
}

await downloadFiles();
await main();
