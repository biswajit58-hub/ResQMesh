enum SimulationStepStatus {
  success('success'),
  warning('warning'),
  rejected('rejected');

  const SimulationStepStatus(this.wire);
  final String wire;
}

class SimulationStep {
  const SimulationStep({
    required this.label,
    required this.detail,
    required this.status,
    required this.fromNode,
    required this.toNode,
    required this.atMillis,
  });

  final String label;
  final String detail;
  final SimulationStepStatus status;
  final String fromNode;
  final String toNode;
  final int atMillis;
}

class ProtocolSimulationReport {
  const ProtocolSimulationReport({
    required this.runId,
    required this.steps,
    required this.deliveredToC,
    required this.duplicateDropped,
    required this.tamperedRejected,
    required this.expiredRejected,
    required this.hopCount,
    required this.generatedAt,
    required this.isSimulation,
  });

  final String runId;
  final List<SimulationStep> steps;
  final bool deliveredToC;
  final bool duplicateDropped;
  final bool tamperedRejected;
  final bool expiredRejected;
  final int hopCount;
  final DateTime generatedAt;

  /// Always true: this exercises the protocol in memory and does not use radios.
  final bool isSimulation;
}
