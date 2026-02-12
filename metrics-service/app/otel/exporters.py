from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.metrics.view import View
try:
    from opentelemetry.sdk.metrics.aggregation import ExplicitBucketHistogramAggregation
except ImportError:
    from opentelemetry.sdk.metrics._internal.aggregation import ExplicitBucketHistogramAggregation
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from prometheus_client import (
    start_http_server,
    REGISTRY,
    PROCESS_COLLECTOR,
    PLATFORM_COLLECTOR,
    GC_COLLECTOR,
)
import logging
from ..config import settings

logger = logging.getLogger(__name__)

# Unregister default collectors that cause "out of order sample" issues on restart.
# These process/platform/gc metrics have timestamps that conflict with AMP's stored
# data when the service restarts, causing the entire metrics batch to be dropped.
try:
    REGISTRY.unregister(PROCESS_COLLECTOR)
except Exception:
    pass

try:
    REGISTRY.unregister(PLATFORM_COLLECTOR)
except Exception:
    pass

try:
    REGISTRY.unregister(GC_COLLECTOR)
except Exception:
    pass


def setup_otel():
    """Setup OpenTelemetry metric providers and exporters."""
    readers = []
    
    try:
        # Create resource with service name
        resource = Resource.create(attributes={
            SERVICE_NAME: settings.OTEL_SERVICE_NAME
        })
        
        # Setup Prometheus exporter if enabled
        if settings.OTEL_PROMETHEUS_ENABLED:
            # Start Prometheus HTTP server
            start_http_server(port=settings.OTEL_PROMETHEUS_PORT, addr="0.0.0.0")
            
            # Create PrometheusMetricReader (no endpoint parameter needed)
            prometheus_reader = PrometheusMetricReader()
            readers.append(prometheus_reader)
            logger.info(f"Prometheus metrics exporter enabled on port {settings.OTEL_PROMETHEUS_PORT}")
        
        # Setup OTLP exporter if endpoint configured
        if settings.OTEL_OTLP_ENDPOINT:
            otlp_exporter = OTLPMetricExporter(
                endpoint=f"{settings.OTEL_OTLP_ENDPOINT}/v1/metrics"
            )
            otlp_reader = PeriodicExportingMetricReader(
                exporter=otlp_exporter,
                export_interval_millis=30000  # 30 seconds
            )
            readers.append(otlp_reader)
            logger.info(f"OTLP metrics exporter enabled for {settings.OTEL_OTLP_ENDPOINT}")
        
        # Create MeterProvider with configured readers and resource
        if readers:
            boundaries = [float(b) for b in settings.HISTOGRAM_BUCKET_BOUNDARIES.split(",")]
            duration_view = View(
                instrument_name="*_duration_seconds",
                aggregation=ExplicitBucketHistogramAggregation(boundaries=boundaries),
            )
            meter_provider = MeterProvider(
                resource=resource,
                metric_readers=readers,
                views=[duration_view],
            )
            metrics.set_meter_provider(meter_provider)
            logger.info("OpenTelemetry metrics configured successfully")
        else:
            logger.warning("No OpenTelemetry exporters configured")
            
    except Exception as e:
        logger.error(f"Failed to setup OpenTelemetry: {e}")
        # Don't fail startup, just log the error
        pass