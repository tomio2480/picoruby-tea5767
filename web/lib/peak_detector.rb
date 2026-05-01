module PeakDetector
  module_function

  def detect(rssi_array, threshold:)
    peaks = []
    cluster_start = nil

    rssi_array.each_with_index do |rssi, i|
      if rssi >= threshold
        cluster_start ||= i
      elsif cluster_start
        peaks << pick_max(rssi_array, cluster_start, i - 1)
        cluster_start = nil
      end
    end

    peaks << pick_max(rssi_array, cluster_start, rssi_array.size - 1) if cluster_start
    peaks
  end

  def pick_max(rssi_array, from, to)
    max_idx = (from..to).max_by { |i| rssi_array[i] }
    { i: max_idx, rssi: rssi_array[max_idx] }
  end
end