--!strict
-- lune run tests/run   (from the roblox folder)

local process = require("@lune/process")

local H = require("./harness")
require("./rules.spec")
require("./data.spec")

local passes, failures = H.results()
print(`\n{passes} passed, {failures} failed`)
process.exit(if failures == 0 then 0 else 1)
