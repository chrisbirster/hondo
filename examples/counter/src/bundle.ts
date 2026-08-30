import { mountCounter } from './runtime.js';

const counter = mountCounter();

type HondoCounterGlobals = typeof globalThis & {
  __hondoCounterIncrement?: () => void;
  __hondoCounterDispose?: () => void;
};

const globals = globalThis as HondoCounterGlobals;
globals.__hondoCounterIncrement = () => counter.increment();
globals.__hondoCounterDispose = () => counter.dispose();
