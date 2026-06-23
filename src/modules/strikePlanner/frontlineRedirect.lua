local AirbaseAttrition = require("src.modules.strikePlanner.airbaseAttrition")
local Utils = require("src.utils.utils")

local FrontlineRedirect = {}

-- ============================================================================
-- Mapping Rewrite
-- ============================================================================

---Apply mapping name rewrites for frontline redirect
---Returns a deep-copied list to avoid mutating shared strike mappings in config.
---@param strikeMappings SBJ__ReconStrikeMapping[] Original mapping list (not mutated)
---@param rules SBJ__StrikeMappingRewriteRule[] Rewrite rules
---@return SBJ__ReconStrikeMapping[] # Copy with names rewritten where applicable
function FrontlineRedirect.rewriteMappings(strikeMappings, rules)
  local result = Utils.deepCopy(strikeMappings)

  for _, mapping in ipairs(result) do
    for _, rule in ipairs(rules) do
      if mapping.type == rule.type and mapping.name:sub(1, #rule.fromPrefix) == rule.fromPrefix then
        mapping.name = rule.toPrefix .. mapping.name:sub(#rule.fromPrefix + 1)
        break
      end
    end
  end
  return result
end

---Apply configured frontline redirect mappings when sticky redirect is active
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context
---@param strikeMappings SBJ__ReconStrikeMapping[] Original mapping list
---@return SBJ__ReconStrikeMapping[] # Original or rewritten mappings
function FrontlineRedirect.applyMappings(config, reconContext, strikeMappings)
  if reconContext.frontlineRedirected and
      config.c.recon.frontlineRedirect and
      config.c.recon.frontlineRedirect.mappings then
    return FrontlineRedirect.rewriteMappings(strikeMappings, config.c.recon.frontlineRedirect.mappings)
  end

  return strikeMappings
end

-- ============================================================================
-- Public API
-- ============================================================================

---Decide whether frontline strike packages should be redirected to rear bases with AAR
---Sticky: mutates reconContext.frontlineRedirected on first trigger; skips recompute thereafter.
---@param config SBJ__Config Configuration data
---@param reconContext SBJ__ReconContext Reconnaissance context (mutated when redirect triggers)
---@return boolean isRedirected Whether redirect is active after this evaluation
---@return string|nil activationMessage Non-nil only on the tick redirect just activated; caller should log it
function FrontlineRedirect.evaluate(config, reconContext)
  if reconContext.frontlineRedirected then
    return true, nil
  end

  local cfg = config.c.recon.frontlineRedirect
  if not cfg or not cfg.enabled then
    return false, nil
  end

  local summary = AirbaseAttrition.calculate(config.c.air.landBased.deployedACs, cfg.frontlineBaseNames)

  if summary.attritionPct >= cfg.attritionThresholdPct then
    reconContext.frontlineRedirected = true
    local msg = string.format(
      "action=activate reason=attrition_threshold_reached attritionPct=%.1f thresholdPct=%.1f expected=%d current=%d",
      summary.attritionPct,
      cfg.attritionThresholdPct,
      summary.expectedTotal,
      summary.currentTotal
    )

    return true, msg
  end

  return false, nil
end

return FrontlineRedirect
