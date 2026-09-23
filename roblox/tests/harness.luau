--!strict
-- A dozen lines of test harness, so the tests need nothing but Lune.

local H = {}
local failures, passes = 0, 0

function H.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passes += 1
		print("  ok   " .. name)
	else
		failures += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

function H.eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(`{what or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function H.near(actual: number, expected: number, eps: number, what: string?)
	if math.abs(actual - expected) > eps then
		error(`{what or "value"}: expected {expected} ± {eps}, got {actual}`, 2)
	end
end

function H.results(): (number, number)
	return passes, failures
end

return H
