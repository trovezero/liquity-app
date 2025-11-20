import { useQuery } from "@tanstack/react-query";
import type { UseQueryResult } from "@tanstack/react-query";
import { useMemo } from "react";
import type { InferOutput } from "valibot";
import * as v from "valibot";

const KnownDelegatesSchema = v.array(
  v.object({
    name: v.string(),
    url: v.string(),
    strategies: v.array(
      v.object({
        name: v.string(),
        address: v.string(),
        branches: v.array(v.string()),
        hide: v.optional(v.boolean(), false),
      }),
    ),
  }),
);

export type KnownDelegates = InferOutput<typeof KnownDelegatesSchema>;

const HARDCODED_DELEGATES: KnownDelegates = [{
  name: "Trove Zero",
  url: "https://trovezero.xyz/",
  strategies: [
    {
      name: "",
      address: "0xe707784292289be3aa0fb6f9d33d420291f98695",
      branches: ["ETH", "wstETH", "rETH"],
      hide: false,
    },
  ],
}];

export function useKnownDelegates(): UseQueryResult<KnownDelegates | null> {
  return useQuery({
    queryKey: ["knownDelegates"],
    queryFn: async () => HARDCODED_DELEGATES,
    initialData: HARDCODED_DELEGATES,
  });
}

export function useDelegateDisplayName(delegateAddress: string | null) {
  const knownDelegatesQuery = useKnownDelegates();

  return useMemo(() => {
    if (!delegateAddress || !knownDelegatesQuery.data) return undefined;

    // branchId could be used for filtering delegates by collateral in the future
    for (const group of knownDelegatesQuery.data) {
      const strategy = group.strategies.find(
        (s) => s.address.toLowerCase() === delegateAddress.toLowerCase(),
      );
      if (strategy) {
        return strategy.name ? `${group.name} - ${strategy.name}` : group.name;
      }
    }
    return undefined;
  }, [delegateAddress, knownDelegatesQuery.data]);
}
